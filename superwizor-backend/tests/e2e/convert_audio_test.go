//go:build e2e
// +build e2e

// convert_audio_test.go — focused e2e coverage of the new
// IngestionService.ConvertAudio RPC (added 2026-05-20).
//
// Why a separate file: full_session_test.go runs the whole STT+LLM
// pipeline (5+ minute poll). For ConvertAudio we only need the
// upload → convert → complete handshake; the Chirp roundtrip is
// covered by the existing happy-path test. Splitting keeps the
// convert test runnable in ~30s, so we can wire it into CI's
// post-deploy smoke gate without blowing the budget.
//
// Run:
//
//	cd superwizor-backend/tests
//	go test -tags=e2e -timeout=3m -v ./e2e/... -run TestConvertAudio_M4AServerConversion
//
// Reuses loadConfig, mintFirebaseSession, dial, hostPort, etc. from
// full_session_test.go (same package, same build tag).

package e2e_test

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

// TestConvertAudio_M4AServerConversion exercises the server-side
// fallback that ingestion-svc exposes when iOS-native or web clients
// can't transcode M4A on-device.
//
// Flow:
//
//	1. Register therapist + patient file (minimal shared setup).
//	2. CreateAudioUpload with content_type=audio/m4a (forces M4A path).
//	3. PUT testdata/sample.m4a to the signed URL.
//	4. ConvertAudio → expect content_type=audio/flac, converted=true.
//	5. ConvertAudio AGAIN → expect converted=false (idempotency).
//	6. CompleteAudioUpload → session created.
//
// We DON'T poll for the STT/LLM terminal status — that's the
// happy-path test's job. The unit on test here is the conversion
// boundary, not the full pipeline.
func TestConvertAudio_M4AServerConversion(t *testing.T) {
	cfg := loadConfig(t)

	// Override the audio fixture to the m4a sibling. AUDIO_FILE env
	// still wins if set — useful for manual probing with a different
	// codec.
	m4aPath := os.Getenv("AUDIO_FILE_M4A")
	if m4aPath == "" {
		m4aPath = "testdata/sample.m4a"
	}
	if !filepath.IsAbs(m4aPath) {
		if abs, err := filepath.Abs(m4aPath); err == nil {
			m4aPath = abs
		}
	}
	st, err := os.Stat(m4aPath)
	require.NoErrorf(t, err,
		"m4a fixture missing at %s — generate via\n"+
			"  ffmpeg -i testdata/sample.wav -c:a aac -b:a 64k testdata/sample.m4a",
		m4aPath)
	m4aSize := st.Size()
	require.Greater(t, m4aSize, int64(1024), "m4a fixture suspiciously small")

	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_uid_conv_%d", runID)
	firebaseEmail := fmt.Sprintf("test_conv_%d@example.com", runID)

	t.Logf("══════════════════════════════════════════════════════════════")
	t.Logf("  E2E ConvertAudio test")
	t.Logf("  Run ID:        %d", runID)
	t.Logf("  M4A fixture:   %s (%d bytes)", m4aPath, m4aSize)
	t.Logf("  Ingestion URL: %s", cfg.ingestionURL)
	t.Logf("══════════════════════════════════════════════════════════════")

	// Step 0 — Firebase ID token
	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()
	var idToken string
	if cfg.preMintedToken != "" {
		idToken = cfg.preMintedToken
	} else {
		fbSession, ferr := mintFirebaseSession(tokenCtx, cfg.projectID,
			cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
		require.NoError(t, ferr, "Firebase token minting")
		t.Cleanup(func() {
			if cerr := fbSession.cleanup(); cerr != nil {
				t.Logf("⚠ Firebase user cleanup failed: %v", cerr)
			}
		})
		idToken = fbSession.IDToken
	}

	// Dial. ConvertAudio lives on ingestion-svc; we still need
	// identity-svc + clinical-svc for the setup steps.
	identityConn := dial(t, cfg.identityURL, idToken)
	defer identityConn.Close()
	clinicalConn := dial(t, cfg.clinicalURL, idToken)
	defer clinicalConn.Close()
	ingestionConn := dial(t, cfg.ingestionURL, idToken)
	defer ingestionConn.Close()

	identityClient := identityv1.NewIdentityServiceClient(identityConn)
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)
	ingestionClient := ingestionv1.NewIngestionServiceClient(ingestionConn)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	// Step 1 — therapist
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
	t.Logf("✓ Therapist: %s", therapist.Id)

	// Step 2 — patient file (we only need a valid id; modality is irrelevant)
	modalities, err := clinicalClient.ListModalities(ctx, &emptypb.Empty{})
	require.NoError(t, err)
	require.NotEmpty(t, modalities.Modalities)
	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId:         therapist.Id,
		ModalityCode:        "CBT",
		WorkingAlias:        fmt.Sprintf("Convert Test %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "convert audio e2e",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-conv-pat-%d", runID),
		PatientFirstName:    "Conv",
		PatientLastName:     "Patient",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err, "CreatePatientFile")
	t.Logf("✓ Patient: %s", patient.Id)
	t.Cleanup(func() {
		bg, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, _ = clinicalClient.DeletePatientFile(bg,
			&clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
	})

	// Step 3 — CreateAudioUpload with content_type=audio/m4a
	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId:              therapist.Id,
		PatientFileId:            patient.Id,
		ContentType:              "audio/m4a",
		EstimatedSizeBytes:       m4aSize,
		EstimatedDurationSeconds: 60,
		IdempotencyKey:           fmt.Sprintf("e2e-conv-up-%d", runID),
		ClientAppVersion:         "e2e-convert-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err, "CreateAudioUpload")
	require.NotEmpty(t, upload.UploadId)
	require.NotEmpty(t, upload.SignedUrl)
	t.Logf("✓ Signed URL granted: upload_id=%s object=%s",
		upload.UploadId, upload.ObjectPath)

	// Step 4 — PUT the M4A
	body, err := os.ReadFile(m4aPath)
	require.NoError(t, err)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut,
		upload.SignedUrl, bytes.NewReader(body))
	require.NoError(t, err)
	for k, v := range upload.RequiredHeaders {
		req.Header.Set(k, v)
	}
	if req.Header.Get("x-goog-meta-source") == "" {
		req.Header.Set("x-goog-meta-source", "superwizor-mobile")
	}
	if req.Header.Get("Content-Type") == "" {
		req.Header.Set("Content-Type", "audio/m4a")
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	require.Equalf(t, http.StatusOK, resp.StatusCode,
		"PUT failed (%d): %s", resp.StatusCode, string(respBody))
	t.Logf("✓ M4A uploaded: %d bytes", m4aSize)

	// Step 5 — ConvertAudio (the unit under test)
	t.Log("\n═══ ConvertAudio (server-side ffmpeg) ═══")
	t0 := time.Now()
	convertResp, err := ingestionClient.ConvertAudio(ctx, &ingestionv1.ConvertAudioRequest{
		AudioUploadId:     upload.UploadId,
		TargetContentType: "audio/flac",
	})
	require.NoError(t, err, "ConvertAudio")
	require.Equal(t, "audio/flac", convertResp.ContentType,
		"server should report FLAC after conversion")
	require.NotEqual(t, upload.ObjectPath, convertResp.ObjectPath,
		"converted object should land at a different path (sibling .flac)")
	require.True(t, convertResp.Converted, "ffmpeg should have run")
	require.Contains(t, convertResp.ObjectPath, ".flac",
		"new object path should end in .flac")
	t.Logf("✓ ConvertAudio done in %s: %s → %s",
		time.Since(t0).Round(time.Millisecond),
		upload.ObjectPath, convertResp.ObjectPath)

	// Step 6 — Idempotency: second call should be a no-op
	t.Log("\n═══ ConvertAudio replay (idempotency) ═══")
	convertResp2, err := ingestionClient.ConvertAudio(ctx, &ingestionv1.ConvertAudioRequest{
		AudioUploadId:     upload.UploadId,
		TargetContentType: "audio/flac",
	})
	require.NoError(t, err, "ConvertAudio replay")
	require.False(t, convertResp2.Converted,
		"replay should be a no-op (converted=false)")
	require.Equal(t, convertResp.ObjectPath, convertResp2.ObjectPath,
		"replay should return the same object_path")
	t.Logf("✓ Replay is no-op: converted=false")

	// Step 7 — CompleteAudioUpload to confirm the row is in a sane state
	complete, err := ingestionClient.CompleteAudioUpload(ctx, &ingestionv1.CompleteAudioUploadRequest{
		UploadId:              upload.UploadId,
		ActualDurationSeconds: 60,
		ActualSizeBytes:       m4aSize,
		ChunkCount:            1,
	})
	require.NoError(t, err, "CompleteAudioUpload")
	require.NotEmpty(t, complete.SessionId)
	t.Logf("✓ Session created post-convert: %s", complete.SessionId)
}

// TestCompleteAudioUpload_RejectsUnconvertedM4A guards the codec gate
// added in CompleteAudioUpload (2026-05-20). Flow:
//
//	1. CreateAudioUpload with content_type=audio/m4a.
//	2. PUT the M4A to the signed URL.
//	3. SKIP ConvertAudio.
//	4. Call CompleteAudioUpload → expect FailedPrecondition.
//
// Failure modes this gate catches:
//   - Client uploads M4A but network fails between PUT and ConvertAudio,
//     client retries from CompleteAudioUpload and skips the convert step.
//   - Buggy future client forgets the ConvertAudio call entirely.
//
// Without the gate, an M4A row would reach stt-worker, Chirp would
// reject it with INVALID_ARGUMENT, and Pub/Sub would retry 6× burning
// Cloud Function compute. The gate turns that into a synchronous client
// error.
func TestCompleteAudioUpload_RejectsUnconvertedM4A(t *testing.T) {
	cfg := loadConfig(t)

	m4aPath := os.Getenv("AUDIO_FILE_M4A")
	if m4aPath == "" {
		m4aPath = "testdata/sample.m4a"
	}
	if !filepath.IsAbs(m4aPath) {
		if abs, err := filepath.Abs(m4aPath); err == nil {
			m4aPath = abs
		}
	}
	st, err := os.Stat(m4aPath)
	require.NoErrorf(t, err, "m4a fixture missing at %s", m4aPath)
	m4aSize := st.Size()

	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_uid_gate_%d", runID)
	firebaseEmail := fmt.Sprintf("test_gate_%d@example.com", runID)

	t.Logf("══════════════════════════════════════════════════════════════")
	t.Logf("  E2E CompleteAudioUpload codec-gate test")
	t.Logf("  Run ID:        %d", runID)
	t.Logf("══════════════════════════════════════════════════════════════")

	// Boilerplate setup (same as TestConvertAudio_M4AServerConversion).
	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()
	var idToken string
	if cfg.preMintedToken != "" {
		idToken = cfg.preMintedToken
	} else {
		fbSession, ferr := mintFirebaseSession(tokenCtx, cfg.projectID,
			cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
		require.NoError(t, ferr, "Firebase token minting")
		t.Cleanup(func() { _ = fbSession.cleanup() })
		idToken = fbSession.IDToken
	}

	identityConn := dial(t, cfg.identityURL, idToken)
	defer identityConn.Close()
	clinicalConn := dial(t, cfg.clinicalURL, idToken)
	defer clinicalConn.Close()
	ingestionConn := dial(t, cfg.ingestionURL, idToken)
	defer ingestionConn.Close()

	identityClient := identityv1.NewIdentityServiceClient(identityConn)
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)
	ingestionClient := ingestionv1.NewIngestionServiceClient(ingestionConn)

	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()

	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid: firebaseUID, Email: firebaseEmail,
		Role: identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName: "E2E", LastName: "Gate",
		UiLanguage: "pl", Timezone: "Europe/Warsaw", HasAcceptedTos: true,
	})
	require.NoError(t, err)

	mods, err := clinicalClient.ListModalities(ctx, &emptypb.Empty{})
	require.NoError(t, err)
	require.NotEmpty(t, mods.Modalities)
	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId: therapist.Id, ModalityCode: "CBT",
		WorkingAlias:        fmt.Sprintf("Gate Test %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "codec-gate e2e",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-gate-pat-%d", runID),
		PatientFirstName:    "Gate", PatientLastName: "Patient",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		bg, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, _ = clinicalClient.DeletePatientFile(bg,
			&clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
	})

	// 1. CreateAudioUpload with content_type=audio/m4a.
	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId: therapist.Id, PatientFileId: patient.Id,
		ContentType:              "audio/m4a",
		EstimatedSizeBytes:       m4aSize,
		EstimatedDurationSeconds: 60,
		IdempotencyKey:           fmt.Sprintf("e2e-gate-up-%d", runID),
		ClientAppVersion:         "e2e-gate-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err)

	// 2. PUT the M4A.
	body, err := os.ReadFile(m4aPath)
	require.NoError(t, err)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, upload.SignedUrl, bytes.NewReader(body))
	require.NoError(t, err)
	for k, v := range upload.RequiredHeaders {
		req.Header.Set(k, v)
	}
	if req.Header.Get("x-goog-meta-source") == "" {
		req.Header.Set("x-goog-meta-source", "superwizor-mobile")
	}
	if req.Header.Get("Content-Type") == "" {
		req.Header.Set("Content-Type", "audio/m4a")
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	rb, _ := io.ReadAll(resp.Body)
	require.Equalf(t, http.StatusOK, resp.StatusCode, "PUT: %d %s", resp.StatusCode, string(rb))
	t.Logf("✓ M4A uploaded; deliberately SKIPPING ConvertAudio")

	// 3. Skip ConvertAudio.

	// 4. CompleteAudioUpload → expect FailedPrecondition with a clear,
	// actionable message naming the ConvertAudio RPC.
	_, err = ingestionClient.CompleteAudioUpload(ctx, &ingestionv1.CompleteAudioUploadRequest{
		UploadId:              upload.UploadId,
		ActualDurationSeconds: 60,
		ActualSizeBytes:       m4aSize,
		ChunkCount:            1,
	})
	require.Error(t, err, "CompleteAudioUpload should reject unconverted M4A")
	s, ok := status.FromError(err)
	require.True(t, ok, "error should be a grpc status; got %T", err)
	require.Equalf(t, codes.FailedPrecondition, s.Code(),
		"expected FailedPrecondition, got %s (%v)", s.Code(), err)
	require.Contains(t, s.Message(), "ConvertAudio",
		"error message should name the remediation RPC")
	require.Contains(t, s.Message(), "audio/m4a",
		"error message should name the offending codec")
	t.Logf("✓ CompleteAudioUpload correctly rejected: %s", s.Message())
}
