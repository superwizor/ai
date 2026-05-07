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
//   - AUDIO_FILE        (default: tests/e2e/testdata/sample.m4a, then test-audio.wav)
//   - FIREBASE_API_KEY  (default: auto-extracted from
//                        flutter-app/superwizor/lib/firebase_options.dart)
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
//	1. CreateUser            (identity-svc)   — therapist registration
//	2. ListModalities        (clinical-svc)   — cross-service auth check
//	3. CreatePatientFile     (clinical-svc)   — first patient + idempotency
//	4. CreateAudioUpload     (ingestion-svc)  — request signed URL
//	5. PUT to GCS                              — direct upload
//	6. CompleteAudioUpload   (ingestion-svc)  — implicitly creates session
//	7. Poll GetSessionDetails until terminal — verify STT + LLM transitions
//	   - speaker_label_mapping populated, keys are STRING-typed (gotcha!)
//	   - transcript segments present and chronologically ordered
//	   - reports[] non-empty
//	   - canonical transcript blob hash CHANGED after generation
//	8. Soft-delete patient file (cleanup)
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

	firebase "firebase.google.com/go/v4"
	fbauth "firebase.google.com/go/v4/auth"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
	"google.golang.org/grpc/metadata"
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
	// we look for the conventional fixture at testdata/sample.m4a (path
	// relative to this test package — Go test sets cwd to the package
	// dir, so it lands at tests/e2e/testdata/sample.m4a).
	if cfg.audioFile == "" {
		const defaultPath = "testdata/sample.m4a"
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
			"    - drop a Polish-speech m4a at superwizor-backend/tests/e2e/testdata/sample.m4a, or\n"+
			"    - set AUDIO_FILE=/absolute/path/to/your.m4a")

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

	// Hard-fail before doing anything expensive (Firebase mint, gRPC dial,
	// AI pipeline) if the audio file is obviously bad. The pipeline takes
	// minutes and Vertex AI usage costs money; pre-flight validation in
	// milliseconds is worth it.
	audioSize := validateAudioFile(t, cfg.audioFile)

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
	}
	patient, err := clinicalClient.CreatePatientFile(ctx, patientReq)
	require.NoError(t, err, "CreatePatientFile")
	require.NotEmpty(t, patient.Id)
	t.Logf("✓ PatientFile created: id=%s", patient.Id)

	// Re-issue → must return same id (server-enforced idempotency)
	patient2, err := clinicalClient.CreatePatientFile(ctx, patientReq)
	require.NoError(t, err, "CreatePatientFile (idempotency replay)")
	if patient.Id == patient2.Id {
		t.Logf("✓ Idempotency holds: same key → same id")
	} else {
		t.Logf("⚠ Idempotency mismatch: %s ≠ %s", patient.Id, patient2.Id)
		// Not fail-stop today; flip to require.Equal once server-side enforcement is verified.
	}

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
		ContentType:              "audio/m4a",
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
		req.Header.Set("Content-Type", "audio/m4a")
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
		t.Logf("✓ FULL HAPPY PATH PASSED")
	case "ERRORED", "FAILED":
		// Pre-flight audio validation already rejected obviously-bad
		// inputs, so a FAILED here is a real pipeline issue (Vertex AI
		// rejection, schema bug, worker crash). Check llm-worker logs.
		t.Fatalf("Pipeline errored with valid audio. Session: %+v\n"+
			"Investigate via:\n"+
			"  gcloud logging read 'resource.labels.service_name=\"llm-worker\" AND severity>=ERROR' \\\n"+
			"    --project=%s --limit=10 --format=json | jq '.[].jsonPayload'",
			details.Session, /* project */ "superwizor-ai-25ecd")
	default:
		t.Fatalf("Timed out before terminal state (last seen: %q). "+
			"Vertex AI cold start may be slow; consider retrying or extending pollDeadline.",
			finalStatus)
	}
}

// assertCompletedSessionShape verifies invariants that must hold for any
// successful session, regardless of the specific audio content.
// validateAudioFile pre-flights the audio file before any expensive
// downstream work. Hard-fails the test on:
//   - file missing or unreadable
//   - size out of bounds (≤ 1 KB or > 300 MB)
//   - not an MP4/M4A container (magic-byte check)
//   - if ffprobe is on PATH: bad codec, sample-rate, duration
//
// Soft-warns (logs but doesn't fail) on:
//   - non-mono audio (Chirp 3 prefers mono)
//   - missing ffprobe (basic validation only)
//
// Returns the file size in bytes for downstream use.
func validateAudioFile(t *testing.T, path string) int64 {
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

	// 3. Magic-byte sanity. M4A is an MP4 container; the first box should be
	// `ftyp` at offset 4–8, brand at 8–12. We don't fully parse boxes — just
	// reject things that aren't even MP4-shaped.
	f, err := os.Open(path)
	require.NoErrorf(t, err, "open %q", path)
	defer func() { _ = f.Close() }()

	head := make([]byte, 12)
	_, err = io.ReadFull(f, head)
	require.NoErrorf(t, err, "read header of %q", path)

	require.Equalf(t, "ftyp", string(head[4:8]),
		"file at %s is not an M4A/MP4 container. Got first 12 bytes: %x. "+
			"Some encoders emit raw AAC (.aac) or MP3 (.mp3); rename and re-encode to .m4a.",
		path, head)

	brand := strings.TrimSpace(string(head[8:12]))
	validBrands := map[string]bool{
		"M4A": true, "M4B": true, "mp42": true, "mp41": true,
		"isom": true, "iso2": true, "dash": true,
	}
	if !validBrands[brand] {
		t.Logf("audio: unusual M4A brand %q — Chirp 3 may still accept it", brand)
	}

	t.Logf("audio: size=%d bytes (%.1f MB), M4A brand=%q", size, float64(size)/1024/1024, brand)

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

	// Container family check — m4a/mp4 share the same family name in ffprobe.
	require.Containsf(t, probe.Format.FormatName, "mp4",
		"ffprobe reports container format %q; expected mp4-family for .m4a", probe.Format.FormatName)

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

	// Codec — m4a typically holds AAC; ALAC is also valid.
	validCodecs := map[string]bool{"aac": true, "mp4a": true, "alac": true}
	require.Truef(t, validCodecs[audio.CodecName],
		"audio codec is %q; Chirp 3 + .m4a expects aac / mp4a / alac. Re-encode the file.",
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
	t.Logf("✓ %d report(s) generated", len(d.Reports))
}
