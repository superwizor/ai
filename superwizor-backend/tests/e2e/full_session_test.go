//go:build e2e
// +build e2e

// Package e2e_test runs end-to-end tests against the staging environment.
//
// These tests are tagged `e2e` so they don't run during `make test` /
// `go test ./...`. Run explicitly:
//
//	cd superwizor-backend/tests
//	go test -tags=e2e -timeout=10m -v ./e2e/... -run TestFullSession_HappyPath
//
// Required environment:
//   - gcloud authenticated (`gcloud auth login` AND `gcloud auth
//     application-default login` — Firebase Admin SDK needs ADC)
//   - GCP_PROJECT_ID    (default: superwizor-ai-25ecd)
//   - GCP_REGION        (default: europe-central2)
//   - AUDIO_FILE        (default: tests/e2e/testdata/sample.flac)
//   - FIREBASE_API_KEY  (default: auto-extracted from
//     flutter-app/superwizor/lib/firebase_options.dart)
//   - FIREBASE_ID_TOKEN (optional; if set, skip token minting entirely)
//
// Auth: services validate Firebase ID tokens via Firebase Admin SDK, so we
// can't use `gcloud auth print-identity-token` (those are signed by Google
// IAM, not Firebase, and the audience claim doesn't match). Instead this
// test creates a Firebase user via Admin SDK, mints a custom token, and
// exchanges it for an ID token via the Firebase REST API.
//
// What's verified end-to-end:
//
//  1. CreateUser            (identity-svc)   — therapist registration
//  2. ListModalities        (clinical-svc)   — cross-service auth check
//  3. CreatePatientFile     (clinical-svc)   — first patient + idempotency
//  4. CreateAudioUpload     (ingestion-svc)  — request signed URL
//  5. PUT to GCS                              — direct upload
//  6. CompleteAudioUpload   (ingestion-svc)  — implicitly creates session
//  7. Poll GetSessionDetails until terminal — verify STT + LLM transitions
//     - speaker_label_mapping populated, keys are STRING-typed (gotcha!)
//     - transcript segments present and chronologically ordered
//     - reports[] non-empty
//     - canonical transcript blob hash CHANGED after generation
//  8. Soft-delete patient file (cleanup)
package e2e_test

import (
	"bytes"
	"context"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"testing"
	"time"

	"cloud.google.com/go/firestore"
	"cloud.google.com/go/pubsub/v2"
	firebase "firebase.google.com/go/v4"
	fbauth "firebase.google.com/go/v4/auth"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

// ============================================================================
// Configuration
// ============================================================================

type config struct {
	projectID      string
	region         string
	identityURL    string
	clinicalURL    string
	ingestionURL   string
	firebaseAPIKey string
	preMintedToken string
	audioFile      string
	pollDeadline   time.Duration
}

func loadConfig(t *testing.T) config {
	t.Helper()

	cfg := config{
		projectID:      envOr("GCP_PROJECT_ID", "superwizor-ai-25ecd"),
		region:         envOr("GCP_REGION", "europe-central2"),
		identityURL:    os.Getenv("IDENTITY_SVC_URL"),
		clinicalURL:    os.Getenv("CLINICAL_SVC_URL"),
		ingestionURL:   os.Getenv("INGESTION_SVC_URL"),
		firebaseAPIKey: os.Getenv("FIREBASE_API_KEY"),
		preMintedToken: os.Getenv("FIREBASE_ID_TOKEN"),
		audioFile:      os.Getenv("AUDIO_FILE"),
		pollDeadline:   5 * time.Minute,
	}

	if cfg.identityURL == "" {
		cfg.identityURL = describeServiceURL(t, "identity-svc", cfg.region, cfg.projectID)
	}
	if cfg.clinicalURL == "" {
		cfg.clinicalURL = describeServiceURL(t, "clinical-svc", cfg.region, cfg.projectID)
	}
	if cfg.ingestionURL == "" {
		cfg.ingestionURL = describeServiceURL(t, "ingestion-svc", cfg.region, cfg.projectID)
	}

	// Resolve audio path. Either AUDIO_FILE points at it explicitly, or
	// we look for the conventional fixture at testdata/sample.flac
	if cfg.audioFile == "" {
		const defaultPath = "testdata/sample.flac"
		if _, err := os.Stat(defaultPath); err == nil {
			abs, _ := filepath.Abs(defaultPath)
			cfg.audioFile = abs
		}
	} else if !filepath.IsAbs(cfg.audioFile) {
		// Make AUDIO_FILE absolute too — log entries downstream are
		// clearer with full paths, and we're about to pass it to ffprobe
		// which is happier with absolute paths anyway.
		if abs, err := filepath.Abs(cfg.audioFile); err == nil {
			cfg.audioFile = abs
		}
	}

	require.NotEmptyf(t, cfg.audioFile,
		"audio file not located.\n"+
			"  Either:\n"+
			"    - drop a Polish-speech flac at superwizor-backend/tests/e2e/testdata/sample.flac, or\n"+
			"    - set AUDIO_FILE=/absolute/path/to/your.flac")

	if cfg.firebaseAPIKey == "" {
		cfg.firebaseAPIKey = autoDetectFirebaseAPIKey(t)
	}

	return cfg
}

// autoDetectFirebaseAPIKey extracts the Web API key from firebase_options.dart
// in the Flutter app — these keys are public (they ship with the app bundle).
// Returns empty string if not found; caller can also pass FIREBASE_API_KEY env.
func autoDetectFirebaseAPIKey(t *testing.T) string {
	t.Helper()
	candidates := []string{
		"../../flutter-app/superwizor/lib/firebase_options.dart",
		"../../../flutter-app/superwizor/lib/firebase_options.dart",
		"../../../../flutter-app/superwizor/lib/firebase_options.dart",
	}
	rx := regexp.MustCompile(`apiKey:\s*'([^']+)'`)
	for _, p := range candidates {
		data, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		if m := rx.FindSubmatch(data); len(m) >= 2 {
			t.Logf("  Firebase API key auto-detected from %s", p)
			return string(m[1])
		}
	}
	return ""
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func describeServiceURL(t *testing.T, service, region, project string) string {
	t.Helper()
	out, err := exec.Command("gcloud", "run", "services", "describe", service,
		"--region="+region, "--project="+project,
		"--format=value(status.url)").Output()
	require.NoErrorf(t, err, "gcloud run services describe %s failed", service)
	url := strings.TrimSpace(string(out))
	require.NotEmptyf(t, url, "service URL for %s is empty", service)
	return url
}

// ============================================================================
// Firebase token minting
// ============================================================================

// firebaseSession holds a minted Firebase ID token + cleanup hook for the
// underlying Firebase user.
type firebaseSession struct {
	UID     string
	Email   string
	IDToken string
	cleanup func() error
}

// mintFirebaseSession creates a Firebase user (idempotent) and exchanges a
// custom token for a real ID token. Requires:
//   - Application Default Credentials (gcloud auth application-default login)
//   - Firebase Admin role for the ADC principal
//   - The Firebase Web API key (for the public REST exchange)
//
// The returned IDToken is what services validate via Firebase Admin SDK
// downstream — `aud` claim equals the Firebase project ID.
func mintFirebaseSession(ctx context.Context, projectID, apiKey, uid, email string) (*firebaseSession, error) {
	if apiKey == "" {
		return nil, errors.New("FIREBASE_API_KEY required (or place flutter-app/.../firebase_options.dart in repo)")
	}

	config := &firebase.Config{
		ProjectID:        projectID,
		ServiceAccountID: fmt.Sprintf("firebase-adminsdk-fbsvc@%s.iam.gserviceaccount.com", projectID),
	}
	app, err := firebase.NewApp(ctx, config)
	if err != nil {
		return nil, fmt.Errorf("firebase init (is application-default-credentials set?): %w", err)
	}
	authClient, err := app.Auth(ctx)
	if err != nil {
		return nil, fmt.Errorf("firebase auth client: %w", err)
	}

	// Create the user. Idempotent — if it already exists we proceed.
	params := (&fbauth.UserToCreate{}).
		UID(uid).
		Email(email).
		EmailVerified(true)
	if _, err := authClient.CreateUser(ctx, params); err != nil &&
		!fbauth.IsUIDAlreadyExists(err) &&
		!fbauth.IsEmailAlreadyExists(err) {
		return nil, fmt.Errorf("firebase create user: %w", err)
	}

	customToken, err := authClient.CustomToken(ctx, uid)
	if err != nil {
		return nil, fmt.Errorf("mint custom token: %w", err)
	}

	// Exchange the custom token for an ID token via the public REST endpoint.
	exchangeBody, _ := json.Marshal(map[string]any{
		"token":             customToken,
		"returnSecureToken": true,
	})
	url := fmt.Sprintf(
		"https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=%s",
		apiKey)
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(exchangeBody))
	if err != nil {
		return nil, fmt.Errorf("build exchange request: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("custom token exchange: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("exchange returned %d: %s", resp.StatusCode, string(body))
	}

	var exchanged struct {
		IDToken      string `json:"idToken"`
		RefreshToken string `json:"refreshToken"`
		ExpiresIn    string `json:"expiresIn"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&exchanged); err != nil {
		return nil, fmt.Errorf("decode exchange response: %w", err)
	}
	if exchanged.IDToken == "" {
		return nil, errors.New("exchange response missing idToken")
	}

	return &firebaseSession{
		UID:     uid,
		Email:   email,
		IDToken: exchanged.IDToken,
		cleanup: func() error {
			bg, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			return authClient.DeleteUser(bg, uid)
		},
	}, nil
}

// ============================================================================
// gRPC dialing + auth
// ============================================================================

// hostPort strips the https:// scheme and appends :443 for grpc.Dial.
func hostPort(serviceURL string) string {
	host := strings.TrimPrefix(serviceURL, "https://")
	host = strings.TrimPrefix(host, "http://")
	host = strings.TrimSuffix(host, "/")
	if !strings.Contains(host, ":") {
		host += ":443"
	}
	return host
}

// authInterceptor injects `authorization: Bearer <token>` on every unary call.
func authInterceptor(token string) grpc.UnaryClientInterceptor {
	return func(ctx context.Context, method string, req, reply any,
		cc *grpc.ClientConn, invoker grpc.UnaryInvoker, opts ...grpc.CallOption) error {
		ctx = metadata.AppendToOutgoingContext(ctx, "authorization", "Bearer "+token)
		return invoker(ctx, method, req, reply, cc, opts...)
	}
}

func dial(t *testing.T, serviceURL, token string) *grpc.ClientConn {
	t.Helper()
	creds := credentials.NewTLS(&tls.Config{MinVersion: tls.VersionTLS12})
	conn, err := grpc.NewClient(hostPort(serviceURL),
		grpc.WithTransportCredentials(creds),
		grpc.WithUnaryInterceptor(authInterceptor(token)),
	)
	require.NoErrorf(t, err, "dial %s", serviceURL)
	return conn
}

// ============================================================================
// The test
// ============================================================================

func TestFullSession_HappyPath(t *testing.T) {
	cfg := loadConfig(t)
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_uid_%d", runID)
	firebaseEmail := fmt.Sprintf("test_%d@example.com", runID)

	t.Logf("══════════════════════════════════════════════════════════════")
	t.Logf("  E2E full-session test")
	t.Logf("  Run ID:        %d", runID)
	t.Logf("  Project:       %s (%s)", cfg.projectID, cfg.region)
	t.Logf("  Audio file:    %s", cfg.audioFile)
	t.Logf("  Identity URL:  %s", cfg.identityURL)
	t.Logf("  Clinical URL:  %s", cfg.clinicalURL)
	t.Logf("  Ingestion URL: %s", cfg.ingestionURL)
	t.Logf("══════════════════════════════════════════════════════════════")

	// 2. Validate fixture sanity
	//    Many audio problems downstream stem from passing silent or 
	//    non-audio files to the pipeline. We do a quick check here.
	audioSize := assertValidAudio(t, cfg.audioFile)

	// ------------------------------------------------------------------------
	// Step 0 — Mint a Firebase ID token (or use the pre-minted one)
	// ------------------------------------------------------------------------
	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()

	var idToken string
	if cfg.preMintedToken != "" {
		t.Logf("Using FIREBASE_ID_TOKEN from env (skipping mint)")
		idToken = cfg.preMintedToken
	} else {
		t.Logf("Minting Firebase ID token for uid=%s ...", firebaseUID)
		fbSession, err := mintFirebaseSession(tokenCtx, cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
		require.NoError(t, err, "Firebase token minting")
		t.Logf("✓ Firebase user + ID token ready")
		t.Cleanup(func() {
			if err := fbSession.cleanup(); err != nil {
				t.Logf("⚠ Firebase user cleanup failed for %s: %v", firebaseUID, err)
			} else {
				t.Logf("✓ cleanup: Firebase user %s deleted", firebaseUID)
			}
		})
		idToken = fbSession.IDToken
	}

	// Dial all three services with the Firebase ID token.
	identityConn := dial(t, cfg.identityURL, idToken)
	defer identityConn.Close()
	clinicalConn := dial(t, cfg.clinicalURL, idToken)
	defer clinicalConn.Close()
	ingestionConn := dial(t, cfg.ingestionURL, idToken)
	defer ingestionConn.Close()

	identityClient := identityv1.NewIdentityServiceClient(identityConn)
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)
	ingestionClient := ingestionv1.NewIngestionServiceClient(ingestionConn)

	ctx, cancel := context.WithTimeout(context.Background(), cfg.pollDeadline+2*time.Minute)
	defer cancel()

	// ------------------------------------------------------------------------
	// Step 1 — Therapist registration
	//   FirebaseUid MUST equal the token's `sub` claim — that's how
	//   identity-svc links the Firebase identity to our `users` row.
	// ------------------------------------------------------------------------
	t.Log("\n═══ Step 1/8: CreateUser (therapist) ═══")
	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid:    firebaseUID,
		Email:          firebaseEmail,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName:      "E2E",
		LastName:       "Therapist",
		UiLanguage:     "pl",
		Timezone:       "Europe/Warsaw",
		HasAcceptedTos: true,
	})
	require.NoError(t, err, "CreateUser")
	require.NotEmpty(t, therapist.Id, "therapist.id is empty")
	t.Logf("✓ Therapist registered: id=%s (firebase_uid=%s)", therapist.Id, firebaseUID)

	// ------------------------------------------------------------------------
	// Step 2 — Cross-service sanity: list modalities
	// ------------------------------------------------------------------------
	t.Log("\n═══ Step 2/8: ListModalities ═══")
	modalities, err := clinicalClient.ListModalities(ctx, &emptypb.Empty{})
	require.NoError(t, err, "ListModalities")
	require.NotEmpty(t, modalities.Modalities, "no modalities seeded")
	t.Logf("✓ Got %d modalities", len(modalities.Modalities))

	// ------------------------------------------------------------------------
	// Step 3 — Patient file + idempotency
	// ------------------------------------------------------------------------
	t.Log("\n═══ Step 3/8: CreatePatientFile (+ idempotency) ═══")
	patientReq := &clinicalv1.CreatePatientFileRequest{
		TherapistId:         therapist.Id,
		ModalityCode:        "CBT",
		WorkingAlias:        fmt.Sprintf("E2E Test Patient %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "E2E test complaint",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-create-patient-%d", runID),
		// Patient-user fields became required in c74fa9d (migration 000013).
		// Without these clinical-svc returns InvalidArgument before even
		// attempting the insert.
		PatientFirstName:    "E2E",
		PatientLastName:     "Patient",
		PatientLanguageCode: "pl",
	}
	patient, err := clinicalClient.CreatePatientFile(ctx, patientReq)
	require.NoError(t, err, "CreatePatientFile")
	require.NotEmpty(t, patient.Id)
	t.Logf("✓ PatientFile created: id=%s", patient.Id)

	// Re-issue → MUST return same id. Migration 000017 + handler
	// pre-check now enforces (therapist_id, idempotency_key) at the
	// data layer; replay short-circuits before the
	// CreatePatientUser / CreatePatientFile inserts and skips the
	// audit log too. If this assertion fails, the handler regressed
	// (the pre-check was bypassed) — see services/clinical-svc/
	// internal/adapters/grpc/server.go::CreatePatientFile.
	patient2, err := clinicalClient.CreatePatientFile(ctx, patientReq)
	require.NoError(t, err, "CreatePatientFile (idempotency replay)")
	require.Equal(t, patient.Id, patient2.Id,
		"idempotency replay returned a different patient_file id — handler is not honoring idempotency_key")
	t.Logf("✓ Idempotency holds: same key → same id (%s)", patient.Id[:8])

	// Schedule cleanup at the end (soft delete, regardless of test outcome)
	t.Cleanup(func() {
		bgCtx, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, delErr := clinicalClient.DeletePatientFile(bgCtx,
			&clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
		if delErr != nil {
			t.Logf("⚠ cleanup: DeletePatientFile failed: %v", delErr)
		} else {
			t.Logf("✓ cleanup: patient file %s soft-deleted", patient.Id)
		}
	})

	// ------------------------------------------------------------------------
	// Step 4 — Request signed upload URL
	// ------------------------------------------------------------------------
	t.Log("\n═══ Step 4/8: CreateAudioUpload (signed URL) ═══")
	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId:              therapist.Id,
		PatientFileId:            patient.Id,
		ContentType:              "audio/flac",
		EstimatedSizeBytes:       audioSize,
		EstimatedDurationSeconds: 600,
		IdempotencyKey:           fmt.Sprintf("e2e-upload-%d", runID),
		ClientAppVersion:         "e2e-test-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err, "CreateAudioUpload")
	require.NotEmpty(t, upload.UploadId, "upload_id missing")
	require.NotEmpty(t, upload.SignedUrl, "signed_url missing")
	t.Logf("✓ Signed URL granted")
	t.Logf("  upload_id:   %s", upload.UploadId)
	t.Logf("  object_path: %s", upload.ObjectPath)

	// ------------------------------------------------------------------------
	// Step 5 — PUT to GCS via signed URL
	// ------------------------------------------------------------------------
	t.Log("\n═══ Step 5/8: PUT to signed URL ═══")
	audioBytes, err := os.ReadFile(cfg.audioFile)
	require.NoError(t, err)

	req, err := http.NewRequestWithContext(ctx, http.MethodPut,
		upload.SignedUrl, bytes.NewReader(audioBytes))
	require.NoError(t, err)

	// Apply required_headers from the signing response. This is the *correct*
	// path — every header the server included in the V4 canonical-signed-
	// headers list MUST be sent on the PUT or GCS rejects with
	// `MalformedSecurityHeader`.
	for k, v := range upload.RequiredHeaders {
		req.Header.Set(k, v)
	}

	// Belt-and-suspenders for known signed headers that older revisions of
	// ingestion-svc forgot to surface in RequiredHeaders. signer.go hard-
	// codes `x-goog-meta-source: superwizor-mobile` into every signature, so
	// we always send it. If the server already populated this in
	// RequiredHeaders the Set is a harmless no-op (same value).
	if req.Header.Get("x-goog-meta-source") == "" {
		req.Header.Set("x-goog-meta-source", "superwizor-mobile")
	}
	if req.Header.Get("Content-Type") == "" {
		req.Header.Set("Content-Type", "audio/flac")
	}

	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err, "PUT signed URL")
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)
	require.Equalf(t, http.StatusOK, resp.StatusCode,
		"PUT to signed URL returned %d: %s", resp.StatusCode, string(body))
	t.Logf("✓ Audio uploaded: HTTP %d, %d bytes", resp.StatusCode, audioSize)

	// ------------------------------------------------------------------------
	// Step 6 — Confirm upload (creates session)
	// ------------------------------------------------------------------------
	t.Log("\n═══ Step 6/8: CompleteAudioUpload (creates session) ═══")
	complete, err := ingestionClient.CompleteAudioUpload(ctx, &ingestionv1.CompleteAudioUploadRequest{
		UploadId:              upload.UploadId,
		ActualDurationSeconds: 600,
		ActualSizeBytes:       audioSize,
		ChunkCount:            1,
		Md5Hash:               "",
	})
	require.NoError(t, err, "CompleteAudioUpload")
	require.NotEmpty(t, complete.SessionId, "session_id not returned")
	t.Logf("✓ Session created: id=%s, processing_started=%v",
		complete.SessionId, complete.ProcessingStarted)

	// ------------------------------------------------------------------------
	// Step 7 — Poll for terminal status
	// ------------------------------------------------------------------------
	t.Log("\n═══ Step 7/8: Poll GetSessionDetails ═══")
	t.Logf("  Allowing up to %s for STT + LLM pipeline.", cfg.pollDeadline)

	terminal := map[string]bool{
		"COMPLETED": true,
		"ERRORED":   true,
		"FAILED":    true,
	}
	deadline := time.Now().Add(cfg.pollDeadline)
	var lastStatus string
	var details *clinicalv1.GetSessionDetailsResponse

	for time.Now().Before(deadline) {
		details, err = clinicalClient.GetSessionDetails(ctx,
			&clinicalv1.GetSessionDetailsRequest{SessionId: complete.SessionId})
		if err == nil && details != nil && details.Session != nil {
			if details.Session.Status != lastStatus {
				t.Logf("  %s status: %s",
					time.Now().Format("15:04:05"), details.Session.Status)
				lastStatus = details.Session.Status
			}
			if terminal[details.Session.Status] {
				break
			}
		}
		select {
		case <-ctx.Done():
			t.Fatalf("context canceled while polling: %v", ctx.Err())
		case <-time.After(5 * time.Second):
		}
	}

	require.NotNil(t, details, "GetSessionDetails returned nil")
	require.NotNil(t, details.Session, "session is nil")
	finalStatus := details.Session.Status
	t.Logf("  Final status: %s", finalStatus)

	// ------------------------------------------------------------------------
	// Step 8 — Verdict + structural assertions on the report
	// ------------------------------------------------------------------------
	t.Log("\n═══ Step 8/8: Assertions ═══")

	switch finalStatus {
	case "COMPLETED":
		assertCompletedSessionShape(t, details)

		// --------------------------------------------------------------
		// Step 8.5 — Firestore notification mirror (Sprint 3.6 / DoD §6.5)
		// --------------------------------------------------------------
		// notification-svc worker writes session_states/{sessionId} on
		// `report.generated`. We give it a short window (the worker
		// runs in parallel with our PG poll, so it's usually already
		// there; cold start can take a few seconds).
		assertFirestoreSessionStateDone(t, ctx, cfg.projectID, complete.SessionId, firebaseUID)

		// --------------------------------------------------------------
		// Step 8.6 — Report rating happy-path (feat/report-customization)
		// --------------------------------------------------------------
		// Exercises clinical-svc.RateReport / GetReportRating against
		// the REAL report produced by the LLM call. The validation-only
		// e2e tests in report_customization_test.go can't cover this
		// path because they use a fake report_id that fails the FK
		// before the handler does anything interesting.
		//
		// What's verified:
		//   - GetReportRating before any rating → NotFound (Flutter
		//     widget cue to render the "Rate this report" prompt).
		//   - RateReport positive happy path → returns the persisted row.
		//   - GetReportRating after → matches the just-rated state.
		//   - RateReport negative with chips + notes → upserts in place
		//     (same UNIQUE(report_id, therapist_id), re-rating allowed
		//     per the design doc — "user changed their mind" semantics).
		//   - GetActiveSuggestion after one negative → still empty
		//     (engine trigger is ≥3 negatives of same chip; one isn't
		//     enough — pins the threshold contract).
		t.Log("\n═══ Step 8.6: Report rating happy-path ═══")
		require.NotEmpty(t, details.Reports, "no reports to rate")
		reportID := details.Reports[0].Id
		require.NotEmpty(t, reportID, "report_id is empty")
		t.Logf("  Rating against report_id=%s", reportID[:8])

		// 8.6a — pre-rating NotFound
		_, getErr := clinicalClient.GetReportRating(ctx, &clinicalv1.GetReportRatingRequest{
			ReportId:    reportID,
			TherapistId: therapist.Id,
		})
		require.Error(t, getErr, "expected NotFound on unrated report")
		require.Equal(t, codes.NotFound, status.Code(getErr),
			"expected NotFound code, got %v", status.Code(getErr))
		t.Logf("  ✓ pre-rating GetReportRating returns NotFound")

		// 8.6b — positive rating happy path
		posResp, err := clinicalClient.RateReport(ctx, &clinicalv1.RateReportRequest{
			ReportId:       reportID,
			TherapistId:    therapist.Id,
			Rating:         "positive",
			Source:         "in_app",
			IdempotencyKey: fmt.Sprintf("e2e-rating-pos-%d", time.Now().Unix()),
		})
		require.NoError(t, err, "RateReport positive")
		require.NotNil(t, posResp.Rating)
		require.Equal(t, "positive", posResp.Rating.Rating)
		require.Empty(t, posResp.Rating.Issues, "positive rating must have empty issues (server clamps)")
		t.Logf("  ✓ RateReport positive → id=%s", posResp.Rating.Id[:8])

		// 8.6c — Get after positive
		got, err := clinicalClient.GetReportRating(ctx, &clinicalv1.GetReportRatingRequest{
			ReportId:    reportID,
			TherapistId: therapist.Id,
		})
		require.NoError(t, err, "GetReportRating after positive")
		require.Equal(t, "positive", got.Rating)
		require.Equal(t, posResp.Rating.Id, got.Id, "Get returned a different row than Rate's response")
		t.Logf("  ✓ GetReportRating returns positive state")

		// 8.6d — negative rating re-rating (upsert)
		negResp, err := clinicalClient.RateReport(ctx, &clinicalv1.RateReportRequest{
			ReportId:    reportID,
			TherapistId: therapist.Id,
			Rating:      "negative",
			Issues:      []string{"za_dlugi", "zly_ton"},
			Notes:       "Trochę za bardzo formalny",
			Source:      "in_app",
			// Different idempotency key — represents an actual "re-rating"
			// flow where the user changed their mind. UNIQUE constraint
			// on (report_id, therapist_id) ensures the row is replaced
			// in place, not duplicated.
			IdempotencyKey: fmt.Sprintf("e2e-rating-neg-%d", time.Now().Unix()),
		})
		require.NoError(t, err, "RateReport negative (re-rating)")
		require.Equal(t, "negative", negResp.Rating.Rating)
		require.Equal(t, []string{"za_dlugi", "zly_ton"}, negResp.Rating.Issues)
		require.Equal(t, "Trochę za bardzo formalny", negResp.Rating.Notes)
		// Same DB row → same ID (upsert, not insert).
		require.Equal(t, posResp.Rating.Id, negResp.Rating.Id,
			"re-rating must UPSERT in place — got a new row instead")
		t.Logf("  ✓ Re-rating negative upserts: same id=%s, issues=%v", negResp.Rating.Id[:8], negResp.Rating.Issues)

		// 8.6e — Suggestion engine still empty after only 1 negative
		// (threshold is ≥3 of same chip; one rating not enough)
		sugg, err := clinicalClient.GetActiveSuggestion(ctx, &clinicalv1.GetActiveSuggestionRequest{
			TherapistId: therapist.Id,
		})
		require.NoError(t, err, "GetActiveSuggestion after 1 negative")
		require.NotNil(t, sugg)
		require.Empty(t, sugg.SuggestionId,
			"engine fired with only 1 negative — should require ≥3 per design doc §6")
		t.Logf("  ✓ Suggestion engine empty after 1 negative rating (threshold ≥3)")

		// --------------------------------------------------------------
		// Step 8.7 — Preferences affect future reports (feat/report-customization)
		// --------------------------------------------------------------
		// End-to-end proof that user-configured report preferences
		// actually shape the generated report. Two-phase:
		//
		//   Phase 1 (already done): therapist had ZERO preferences set
		//   when the first report was generated in Step 7 — so report1
		//   uses the standard/default cap (geminiMaxOutReportDefault =
		//   4096) and no preference fragment in the call-2 prompt.
		//
		//   Phase 2 (this step): bump preferences to "detailed" length
		//   + a substantive free_text directive, then re-publish
		//   transcript.completed for the SAME session_id. llm-worker
		//   loads the new preferences via the SessionContext JOIN and
		//   produces a NEW report (reports rows are insert-not-upsert)
		//   that should reflect the bumped budget + the prompt
		//   addition.
		//
		// Assertion: report2.Content is measurably longer than
		// report1.Content. Soft threshold (≥15%) accounts for LLM
		// stochasticity — detailed-mode cap is 8192 vs default 4096,
		// so 2× headroom is available, but the model only fills what
		// the prompt asks for. The DOCELOWA DŁUGOŚĆ directive +
		// section-emphasis nudge from free_text should push the model
		// to use more of that headroom on the same input.
		//
		// We avoid asserting on the free_text content itself appearing
		// verbatim in the report — too prompt-specific and the LLM
		// summarizes/rephrases. Length is the most reliable
		// observable signal.
		t.Log("\n═══ Step 8.7: Preferences affect future reports ═══")

		// 8.7a — Update preferences to detailed length + free_text guidance
		_, err = identityClient.UpdateReportPreferences(ctx, &identityv1.UpdateReportPreferencesRequest{
			TherapistId: therapist.Id,
			Preferences: &identityv1.ReportPreferences{
				Length: "detailed",
				FreeText: "Skupiaj się szczególnie na obserwacjach języka ciała pacjenta " +
					"i kontakcie wzrokowym; rozwiń wątek dynamiki relacji terapeutycznej " +
					"oraz wzorców komunikacji niewerbalnej. Cytuj fragmenty wypowiedzi tam, " +
					"gdzie jest to istotne dla obserwacji klinicznych.",
			},
			IdempotencyKey: fmt.Sprintf("e2e-prefs-detailed-%d", time.Now().Unix()),
		})
		require.NoError(t, err, "UpdateReportPreferences (detailed)")
		t.Logf("  ✓ updated preferences: length=detailed + free_text guidance")

		// 8.7b — Snapshot report1 for comparison
		require.NotEmpty(t, details.Reports, "no baseline report to compare against")
		report1 := details.Reports[0]
		require.NotNil(t, details.Transcript, "session has no transcript")
		transcriptID := details.Transcript.Id
		t.Logf("  baseline report id=%s, content length=%d chars",
			report1.Id[:8], len(report1.Content))

		// 8.7c — Republish transcript.completed → llm-worker reprocesses
		// with the new preferences. New report row appears in the
		// reports table for the same session.
		publishTranscriptCompletedRetry(t, ctx, cfg.projectID, complete.SessionId, transcriptID)
		t.Logf("  ✓ republished transcript.completed for session %s",
			complete.SessionId[:8])

		// 8.7d — Poll for the second report (the one whose id differs
		// from report1's). Re-run typically completes in 10-30s; give
		// 3 min for cold-start headroom.
		report2Deadline := time.Now().Add(3 * time.Minute)
		var report2 *clinicalv1.Report
		for time.Now().Before(report2Deadline) {
			details2, err := clinicalClient.GetSessionDetails(ctx,
				&clinicalv1.GetSessionDetailsRequest{SessionId: complete.SessionId})
			if err == nil && len(details2.Reports) >= 2 {
				for _, r := range details2.Reports {
					if r.Id != report1.Id {
						report2 = r
						break
					}
				}
				if report2 != nil {
					break
				}
			}
			select {
			case <-ctx.Done():
				t.Fatal("context cancelled while polling for second report")
			case <-time.After(5 * time.Second):
			}
		}
		require.NotNil(t, report2,
			"second report did not appear within 3min — preferences may not have triggered regeneration")
		t.Logf("  ✓ second report id=%s, content length=%d chars",
			report2.Id[:8], len(report2.Content))

		// 8.7e — Compare lengths
		ratio := float64(len(report2.Content)) / float64(len(report1.Content))
		t.Logf("  length ratio (report2/report1): %.2fx", ratio)
		assert.Greater(t, len(report2.Content), int(float64(len(report1.Content))*1.15),
			"expected detailed-length pref to produce ≥15%% longer report; "+
				"got report2=%d vs report1=%d chars (ratio %.2fx). LLM may have "+
				"underproduced — check the call-2 prompt directive is reaching the model.",
			len(report2.Content), len(report1.Content), ratio)

		// --------------------------------------------------------------
		// Step 9 — RODO cascade verification
		// --------------------------------------------------------------
		// Now that we have a real kartoteka with a real session + real
		// transcript + real reports, exercise DeletePatientUser and
		// verify the cascade chain (added in 3fd4f20):
		//   patient_user → patient_files (000014 CASCADE) → sessions
		//   → transcripts → reports → hitop_measurements
		//
		// After delete:
		//   - GetPatientFile must return NotFound
		//   - GetSessionDetails for the just-completed session must
		//     also NotFound (proves the cascade reached sessions)
		//
		// This subsumes what the lifecycle suite tests at the RPC layer
		// but with real downstream data — the only place we prove the
		// cascade actually wipes a session that has STT/LLM artifacts.
		t.Log("\n═══ Step 9/9: DeletePatientUser cascade verification ═══")
		_, delErr := clinicalClient.DeletePatientUser(ctx, &clinicalv1.DeletePatientUserRequest{
			PatientFileId: patient.Id,
		})
		require.NoError(t, delErr, "DeletePatientUser")
		t.Logf("✓ DeletePatientUser returned OK (Empty)")

		// patient_file: NotFound
		_, gpfErr := clinicalClient.GetPatientFile(ctx, &clinicalv1.GetPatientFileRequest{
			PatientFileId: patient.Id,
		})
		require.Error(t, gpfErr, "GetPatientFile must NotFound after cascade")
		if st, ok := status.FromError(gpfErr); ok {
			assert.Equal(t, codes.NotFound, st.Code(),
				"kartoteka must be unreachable after DeletePatientUser cascade")
		}

		// session: NotFound (the real cascade test — sessions live
		// behind patient_files; if the FK didn't cascade properly the
		// session row would still be readable).
		_, gsdErr := clinicalClient.GetSessionDetails(ctx, &clinicalv1.GetSessionDetailsRequest{
			SessionId: complete.SessionId,
		})
		require.Error(t, gsdErr, "GetSessionDetails must NotFound after cascade")
		if st, ok := status.FromError(gsdErr); ok {
			assert.Equal(t, codes.NotFound, st.Code(),
				"session must be unreachable after DeletePatientUser cascade")
		}
		t.Logf("✓ Cascade verified: kartoteka + session both gone")
		t.Logf("✓ FULL HAPPY PATH PASSED (incl. Firestore mirror + RODO cascade)")
	case "ERRORED", "FAILED":
		// Pre-flight audio validation already rejected obviously-bad
		// inputs, so a FAILED here is a real pipeline issue (Vertex AI
		// rejection, schema bug, worker crash). Check llm-worker logs.
		t.Fatalf("Pipeline errored with valid audio. Session: %+v\n"+
			"Investigate via:\n"+
			"  gcloud logging read 'resource.labels.service_name=\"llm-worker\" AND severity>=ERROR' \\\n"+
			"    --project=%s --limit=10 --format=json | jq '.[].jsonPayload'",
			details.Session /* project */, "superwizor-ai-25ecd")
	default:
		t.Fatalf("Timed out before terminal state (last seen: %q). "+
			"Vertex AI cold start may be slow; consider retrying or extending pollDeadline.",
			finalStatus)
	}
}

// assertFirestoreSessionStateDone polls session_states/{sessionId} for up
// to 30 s and asserts the worker wrote status="done" with the correct
// therapistFirebaseUid. Cleanup deletes the doc + the matching inbox
// notification (best-effort — Firestore TTL would handle it eventually).
//
// We poll because the notification worker runs as a Cloud Function on a
// separate Pub/Sub subscription and races with our `clinical-svc` poll —
// usually it's already there by the time we're here, but on cold start it
// can lag by a few seconds.
func assertFirestoreSessionStateDone(
	t *testing.T,
	ctx context.Context,
	projectID, sessionID, expectedFirebaseUID string,
) {
	t.Helper()

	fsClient, err := firestore.NewClient(ctx, projectID)
	require.NoError(t, err, "Firestore client init failed")
	defer func() { _ = fsClient.Close() }()

	docPath := "session_states/" + sessionID
	deadline := time.Now().Add(30 * time.Second)
	var doc *firestore.DocumentSnapshot
	var lastErr error

	for time.Now().Before(deadline) {
		doc, lastErr = fsClient.Doc(docPath).Get(ctx)
		if lastErr == nil && doc.Exists() {
			data := doc.Data()
			if data["status"] == "done" {
				break
			}
			t.Logf("  Firestore status=%v (waiting for 'done')…", data["status"])
		}
		select {
		case <-ctx.Done():
			t.Fatalf("context canceled while polling Firestore: %v", ctx.Err())
		case <-time.After(2 * time.Second):
		}
	}

	require.NoErrorf(t, lastErr, "Firestore Get(%s) never succeeded", docPath)
	require.NotNil(t, doc, "doc nil")
	require.True(t, doc.Exists(),
		"Firestore doc %s missing — notification-worker-on-report did not run "+
			"(check Cloud Functions logs for the function with that name; common "+
			"cause: SA missing roles/datastore.user)", docPath)

	data := doc.Data()
	assert.Equal(t, "done", data["status"],
		"Firestore status not 'done' even after polling — worker started but failed mid-write")
	assert.Equal(t, expectedFirebaseUID, data["therapistFirebaseUid"],
		"therapistFirebaseUid mismatch — common cause: writer used users.id (PG UUID) "+
			"instead of users.firebase_uid; Flutter rules will then deny reads")
	assert.Equal(t, sessionID, data["sessionId"], "sessionId in doc != sessionId we wrote")

	t.Logf("✓ Firestore session_states/%s status=done firebase_uid=%s",
		sessionID, expectedFirebaseUID)

	// Cleanup: delete the session_state doc and any inbox docs we created.
	t.Cleanup(func() {
		ctxClean, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		// session_state
		if _, err := fsClient.Doc(docPath).Delete(ctxClean); err != nil {
			t.Logf("⚠ Firestore session_states cleanup failed: %v", err)
		} else {
			t.Logf("✓ cleanup: Firestore %s deleted", docPath)
		}

		// inbox docs for this user — could be multiple if other tests ran;
		// we only purge the ones referencing OUR sessionId.
		inboxPath := fmt.Sprintf("user_notifications/%s/inbox", expectedFirebaseUID)
		iter := fsClient.Collection(inboxPath).Where("sessionId", "==", sessionID).Documents(ctxClean)
		defer iter.Stop()
		var purged int
		for {
			d, err := iter.Next()
			if err != nil {
				break
			}
			if _, err := d.Ref.Delete(ctxClean); err == nil {
				purged++
			}
		}
		if purged > 0 {
			t.Logf("✓ cleanup: %d inbox doc(s) deleted under %s", purged, inboxPath)
		}
	})
}

// assertCompletedSessionShape verifies invariants that must hold for any
// successful session, regardless of the specific audio content.
// assertValidAudio pre-flights the audio file before any expensive
// downstream work. Hard-fails the test on:
//   - file missing or unreadable
//   - size out of bounds (≤ 1 KB or > 300 MB)
//   - not a FLAC file (magic-byte check)
//   - if ffprobe is on PATH: bad codec, sample-rate, duration
//
// Soft-warns (logs but doesn't fail) on:
//   - non-mono audio (Chirp 3 prefers mono)
//   - missing ffprobe (basic validation only)
//
// assertValidAudio does fail-fast sanity checks on the fixture.
func assertValidAudio(t *testing.T, path string) int64 {
	t.Helper()

	const (
		minSize = 1024              // 1 KB; the legacy test-audio.wav stub is 5 bytes
		maxSize = 300 * 1024 * 1024 // 300 MB; matches the signed-URL constraint
		minDur  = 1.0               // seconds
		maxDur  = 90 * 60.0         // 90 minutes — generous session ceiling
	)

	// 1. File exists and is readable
	fi, err := os.Stat(path)
	require.NoErrorf(t, err, "audio file not accessible at %q", path)
	require.Falsef(t, fi.IsDir(), "audio path %q is a directory", path)

	// 2. Size bounds
	size := fi.Size()
	require.GreaterOrEqualf(t, size, int64(minSize),
		"audio file is suspiciously small (%d bytes); likely a placeholder. "+
			"Drop a real Polish-speech m4a at %s, or set AUDIO_FILE.", size, path)
	require.LessOrEqualf(t, size, int64(maxSize),
		"audio file is %d bytes (%d MB); the signed-URL contract caps at %d MB.",
		size, size/1024/1024, maxSize/1024/1024)

	// 3. Magic-byte sanity. FLAC files start with "fLaC".
	//    We don't fully parse them — just reject things that aren't FLAC.
	f, err := os.Open(path)
	require.NoErrorf(t, err, "open %q", path)
	defer func() { _ = f.Close() }()

	head := make([]byte, 12)
	_, err = io.ReadFull(f, head)
	require.NoErrorf(t, err, "read header of %q", path)

	require.Equalf(t, "fLaC", string(head[0:4]),
		"file at %s is not a FLAC file. Got first 4 bytes: %x. "+
			"The app currently uses FLAC; rename and re-encode to .flac.",
		path, head[0:4])

	t.Logf("audio: size=%d bytes (%.1f MB), FLAC magic byte found", size, float64(size)/1024/1024)

	// 4. Optional rich validation via ffprobe. Fail-fast on bad codec /
	// duration / sample rate; soft-warn on stereo (Chirp 3 still works on
	// stereo, just with lower confidence in our experience).
	ffprobe, err := exec.LookPath("ffprobe")
	if err != nil {
		t.Logf("audio: ffprobe not on PATH — skipping codec/duration/sample-rate checks. " +
			"Install with `brew install ffmpeg` for stronger pre-flight validation.")
		return size
	}

	out, err := exec.Command(ffprobe,
		"-v", "error",
		"-print_format", "json",
		"-show_format",
		"-show_streams",
		path,
	).Output()
	require.NoErrorf(t, err, "ffprobe failed on %q", path)

	var probe struct {
		Streams []struct {
			CodecType  string `json:"codec_type"`
			CodecName  string `json:"codec_name"`
			Channels   int    `json:"channels"`
			SampleRate string `json:"sample_rate"`
			Duration   string `json:"duration"`
		} `json:"streams"`
		Format struct {
			FormatName string `json:"format_name"`
			Duration   string `json:"duration"`
		} `json:"format"`
	}
	require.NoError(t, json.Unmarshal(out, &probe), "parse ffprobe output")

	// Container family check — ffprobe reports "flac" for native FLAC files.
	require.Containsf(t, probe.Format.FormatName, "flac",
		"ffprobe reports container format %q; expected flac. Re-encode with ffmpeg -c:a flac.",
		probe.Format.FormatName)

	// Locate the audio stream
	var audio *struct {
		CodecType  string `json:"codec_type"`
		CodecName  string `json:"codec_name"`
		Channels   int    `json:"channels"`
		SampleRate string `json:"sample_rate"`
		Duration   string `json:"duration"`
	}
	for i := range probe.Streams {
		if probe.Streams[i].CodecType == "audio" {
			audio = &probe.Streams[i]
			break
		}
	}
	require.NotNilf(t, audio, "no audio stream found in %q", path)

	// Codec — Chirp 3 supports FLAC natively; we standardised on it because
	// M4A/AAC was returning INTERNAL errors from BatchRecognize on the
	// europe-central2 endpoint.
	require.Equalf(t, "flac", audio.CodecName,
		"audio codec is %q; Chirp 3 + .flac expects codec=flac. Re-encode with `ffmpeg -i in.m4a -c:a flac -ac 1 -ar 16000 out.flac`.",
		audio.CodecName)

	// Sample rate — Chirp 3 spec is 8 kHz – 48 kHz.
	sr, err := strconv.Atoi(audio.SampleRate)
	require.NoErrorf(t, err, "parse sample_rate %q", audio.SampleRate)
	require.GreaterOrEqualf(t, sr, 8000,
		"sample rate is %d Hz; Chirp 3 minimum is 8000 Hz", sr)
	require.LessOrEqualf(t, sr, 48000,
		"sample rate is %d Hz; Chirp 3 maximum is 48000 Hz", sr)

	// Channel count — soft-warn on stereo.
	if audio.Channels != 1 {
		t.Logf("audio: %d channels — Chirp 3 prefers mono (1ch). Test will continue, "+
			"but expect lower transcription confidence. Re-encode with `-ac 1` for best results.",
			audio.Channels)
	}

	// Duration. Use stream duration first, fall back to format duration.
	durStr := audio.Duration
	if durStr == "" {
		durStr = probe.Format.Duration
	}
	dur, err := strconv.ParseFloat(durStr, 64)
	require.NoErrorf(t, err, "parse duration %q", durStr)
	require.GreaterOrEqualf(t, dur, minDur,
		"audio is %.2fs — too short to be a meaningful test (minimum %.0fs)", dur, minDur)
	require.LessOrEqualf(t, dur, maxDur,
		"audio is %.2fs (%.1f min) — exceeds the %.0f-min ceiling for a single session", dur, dur/60, maxDur/60)

	t.Logf("audio: codec=%s, %d ch, %d Hz, duration=%.2fs",
		audio.CodecName, audio.Channels, sr, dur)

	return size
}

func assertCompletedSessionShape(t *testing.T, d *clinicalv1.GetSessionDetailsResponse) {
	t.Helper()
	s := d.Session

	// Reports populated.
	require.NotEmpty(t, d.Reports, "expected at least one report")

	// Speaker label mapping must be populated and JSON-serializable with
	// STRING-typed keys (gotcha documented in docs/agents/09_testing.md).
	require.NotEmpty(t, s.SpeakerLabelMapping, "speaker_label_mapping must be populated")
	for k, v := range s.SpeakerLabelMapping {
		assert.NotEmptyf(t, v, "speaker_label_mapping[%q] is empty", k)
		// Keys are strings in proto (`map<string, string>`), but they must
		// represent integers — otherwise downstream code (and the LLM
		// prompt) won't be able to round-trip them to chunk_idx.
		_, err := strconv.Atoi(k)
		assert.NoErrorf(t, err, "speaker_label_mapping key %q must parse as int", k)
	}

	// Confirm it's at least round-trippable as JSON to catch any oddities.
	if b, err := json.Marshal(s.SpeakerLabelMapping); assert.NoError(t, err) {
		var roundTrip map[string]string
		assert.NoError(t, json.Unmarshal(b, &roundTrip))
		assert.Equal(t, len(s.SpeakerLabelMapping), len(roundTrip))
	}

	// Transcript present and chronologically ordered.
	require.NotNil(t, d.Transcript, "transcript must be present")
	require.NotEmpty(t, d.Transcript.Segments, "transcript must have segments")

	var prevEnd int32
	for i, seg := range d.Transcript.Segments {
		assert.GreaterOrEqualf(t, seg.StartOffsetMs, prevEnd,
			"segment %d (start=%d) must not start before previous segment ended (%d)",
			i, seg.StartOffsetMs, prevEnd)
		assert.GreaterOrEqualf(t, seg.EndOffsetMs, seg.StartOffsetMs,
			"segment %d has end (%d) < start (%d)", i, seg.EndOffsetMs, seg.StartOffsetMs)
		prevEnd = seg.EndOffsetMs

		// Each segment should reference a known speaker tag.
		_, ok := s.SpeakerLabelMapping[strconv.Itoa(int(seg.SpeakerTag))]
		assert.Truef(t, ok || seg.SpeakerTag == 0,
			"segment %d has speaker_tag=%d not present in speaker_label_mapping",
			i, seg.SpeakerTag)
	}

	t.Logf("✓ %d transcript segments (chronologically ordered)", len(d.Transcript.Segments))
	t.Logf("✓ %d speakers in label mapping: %v", len(s.SpeakerLabelMapping), s.SpeakerLabelMapping)

	// Speaker-grouped view (added in feat/clinical-svc-update). The Turns
	// field collapses consecutive same-speaker segments into one block —
	// what Flutter's read-only transcript view renders. Validate four
	// invariants:
	//   1. turns are present whenever segments are present
	//   2. turns are chronologically ordered (sorted by start_offset_ms)
	//   3. adjacent turns have different speaker_tag OR speaker_label
	//      (boundary trigger from grouping.GroupSegmentsIntoTurns)
	//   4. each turn's speaker_tag is in the session's label mapping
	//      (or 0 for the pre-diarization placeholder branch)
	//   5. sum of segments across all turns equals total segment count
	//      — proves the grouping doesn't drop or duplicate chunks
	require.NotEmpty(t, d.Transcript.Turns,
		"transcript.turns must be non-empty when segments are present (speaker-grouped view)")

	var prevTurnEnd int32
	var prevTag int32 = -1 // -1 is impossible for a real tag → first turn always passes the boundary check
	var prevLabel = "\x00impossible-label\x00"
	totalSegmentsInTurns := int32(0)
	for i, turn := range d.Transcript.Turns {
		assert.GreaterOrEqualf(t, turn.StartOffsetMs, prevTurnEnd,
			"turn %d (start=%d) must not start before previous turn ended (%d)",
			i, turn.StartOffsetMs, prevTurnEnd)
		assert.GreaterOrEqualf(t, turn.EndOffsetMs, turn.StartOffsetMs,
			"turn %d has end (%d) < start (%d)", i, turn.EndOffsetMs, turn.StartOffsetMs)

		// Boundary invariant: adjacent turns differ on tag or label.
		// If they don't, grouping logic merged something it shouldn't have.
		if i > 0 {
			sameTag := turn.SpeakerTag == prevTag
			sameLabel := turn.SpeakerLabel == prevLabel
			assert.Falsef(t, sameTag && sameLabel,
				"turn %d has same speaker_tag=%d AND speaker_label=%q as previous turn — should have been merged by grouping",
				i, turn.SpeakerTag, turn.SpeakerLabel)
		}

		// Each turn's tag must be resolvable (or 0 for pre-diarization).
		_, ok := s.SpeakerLabelMapping[strconv.Itoa(int(turn.SpeakerTag))]
		assert.Truef(t, ok || turn.SpeakerTag == 0,
			"turn %d has speaker_tag=%d not present in speaker_label_mapping", i, turn.SpeakerTag)

		// segment_count must be a positive int — a zero would mean
		// an empty turn slipped through the builder.
		assert.Greaterf(t, turn.SegmentCount, int32(0),
			"turn %d has segment_count=0 — empty turn should never be emitted", i)
		totalSegmentsInTurns += turn.SegmentCount

		// Turn text shouldn't be wholly empty unless every underlying
		// segment also was — defensive coverage for the join logic.
		// Allowed to be empty when every contributing segment was empty
		// (rare KMS-rotation case); not fatal, just logged.
		if turn.Text == "" {
			t.Logf("note: turn %d has empty text across %d segments (all underlying chunks were empty after decrypt)",
				i, turn.SegmentCount)
		}

		prevTurnEnd = turn.EndOffsetMs
		prevTag = turn.SpeakerTag
		prevLabel = turn.SpeakerLabel
	}

	// Invariant 5: turns must cover every segment exactly once.
	assert.Equalf(t, int32(len(d.Transcript.Segments)), totalSegmentsInTurns,
		"sum of turn.segment_count (%d) must equal total transcript.segments (%d) — grouping must not drop or duplicate",
		totalSegmentsInTurns, len(d.Transcript.Segments))

	t.Logf("✓ %d speaker turns (grouped from %d segments)", len(d.Transcript.Turns), len(d.Transcript.Segments))
	t.Logf("✓ %d report(s) generated", len(d.Reports))
}

// publishTranscriptCompletedRetry publishes a fresh transcript.completed
// event to the Pub/Sub topic for the given session, triggering an
// llm-worker re-run against the EXISTING transcript blob (no STT
// rerun, no audio re-upload). Used by TestFullSession_HappyPath Step
// 8.7 to validate that report_preferences updates affect the next
// generated report.
//
// Message shape matches what stt-worker emits (see
// services/ai-pipeline-svc/internal/adapters/pubsub/publisher.go):
//
//	{ "session_id": "...", "transcript_id": "..." }
//
// Eventarc wraps this in a CloudEvent envelope before delivering to
// llm-worker, which extracts via MessagePublishedData. We publish
// the raw JSON; the wrapper is automatic.
func publishTranscriptCompletedRetry(t *testing.T, ctx context.Context, projectID, sessionID, transcriptID string) {
	t.Helper()
	client, err := pubsub.NewClient(ctx, projectID)
	require.NoError(t, err, "pubsub.NewClient")
	defer client.Close()

	publisher := client.Publisher(
		fmt.Sprintf("projects/%s/topics/transcript.completed", projectID))
	defer publisher.Stop()

	payload := fmt.Sprintf(`{"session_id":"%s","transcript_id":"%s"}`,
		sessionID, transcriptID)
	result := publisher.Publish(ctx, &pubsub.Message{Data: []byte(payload)})
	_, err = result.Get(ctx)
	require.NoError(t, err, "publish transcript.completed")
}
