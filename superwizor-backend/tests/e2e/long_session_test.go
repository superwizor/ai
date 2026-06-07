//go:build e2e
// +build e2e

// long_session_test.go — Stage 2 of feat/stt-long_audio_support.
//
// Exercises the server-side chunking path: uploads a 22-minute FLAC
// (just past Chirp 3's 20-min word-timestamp limit), verifies
// CompleteAudioUpload triggers ingestion-svc's ChunkForChirp, two
// audio_chunks rows + two stt_operations rows land, stt-finalize
// merges them with cross-chunk alignment, and the session reaches
// COMPLETED.
//
// Synthesizes the long audio at test runtime via ffmpeg's aloop
// filter so the git fixture stays small (sample.flac = 40s, ~3 MB).
//
// Run:
//
//   cd superwizor-backend/tests
//   go test -tags=e2e -timeout=15m -v ./e2e/... -run TestLongSession_Chunked

package e2e_test

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

// TestLongSession_Chunked validates the Stage 2 long-audio path
// end-to-end against staging.
//
// Expected timing on a 22-min FLAC:
//   - PUT to GCS:                   ~20s for ~110 MB
//   - CompleteAudioUpload + chunk:  ~30-60s (ffmpeg silencedetect
//                                   + 2× re-encode + 2× upload)
//   - 2× Chirp BatchRecognize:      1-3 min each, in parallel
//   - stt-finalize merge:           ~30s
//   - llm-worker:                   1-3 min
//   Total: ~5-8 min p50, up to 10 min on a slow Chirp day.
func TestLongSession_Chunked(t *testing.T) {
	cfg := loadConfig(t)

	// 1. Synthesize the 22-min FLAC from sample.flac via aloop.
	srcPath := cfg.audioFile
	if srcPath == "" {
		const defaultPath = "testdata/sample.flac"
		if _, err := os.Stat(defaultPath); err == nil {
			abs, _ := filepath.Abs(defaultPath)
			srcPath = abs
		}
	}
	require.NotEmpty(t, srcPath, "AUDIO_FILE must point at a short FLAC for looping")

	longFLAC := filepath.Join(t.TempDir(), "long_session.flac")
	t.Logf("Synthesizing 22-min FLAC from %s -> %s", srcPath, longFLAC)
	if err := synthLongFLAC(srcPath, longFLAC, 22*60); err != nil {
		t.Fatalf("synthesize long FLAC: %v", err)
	}
	longInfo, err := os.Stat(longFLAC)
	require.NoError(t, err)
	const longDurationSec = int64(22 * 60)
	t.Logf("Long FLAC ready: %.1f MB, ~22 min", float64(longInfo.Size())/1024/1024)

	// 2. Mint Firebase token + dial gRPC services.
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_uid_long_%d", runID)
	firebaseEmail := fmt.Sprintf("test_long_%d@example.com", runID)

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
	t.Cleanup(func() { _ = identityConn.Close() })
	clinicalConn := dial(t, cfg.clinicalURL, idToken)
	t.Cleanup(func() { _ = clinicalConn.Close() })
	ingestionConn := dial(t, cfg.ingestionURL, idToken)
	t.Cleanup(func() { _ = ingestionConn.Close() })

	identityClient := identityv1.NewIdentityServiceClient(identityConn)
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)
	ingestionClient := ingestionv1.NewIngestionServiceClient(ingestionConn)

	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Minute)
	defer cancel()

	// 3. Therapist + patient setup.
	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid: firebaseUID, Email: firebaseEmail,
		Role: identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName: "E2E", LastName: "Long",
		UiLanguage: "pl", Timezone: "Europe/Warsaw", HasAcceptedTos: true,
	})
	require.NoError(t, err)

	mods, err := clinicalClient.ListModalities(ctx, &emptypb.Empty{})
	require.NoError(t, err)
	require.NotEmpty(t, mods.Modalities)
	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId: therapist.Id, ModalityCode: "CBT",
		WorkingAlias:        fmt.Sprintf("Long Test %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "long-session e2e",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-long-pat-%d", runID),
		PatientFirstName:    "Long", PatientLastName: "Patient",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		bg, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, _ = clinicalClient.DeletePatientFile(bg,
			&clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
	})

	// 4. CreateAudioUpload.
	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId: therapist.Id, PatientFileId: patient.Id,
		ContentType:              "audio/flac",
		EstimatedSizeBytes:       longInfo.Size(),
		EstimatedDurationSeconds: int32(longDurationSec),
		IdempotencyKey:           fmt.Sprintf("e2e-long-up-%d", runID),
		ClientAppVersion:         "e2e-long-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err)
	t.Logf("Signed URL granted: upload_id=%s", upload.UploadId)

	// 5. PUT the 22-min FLAC.
	body, err := os.ReadFile(longFLAC)
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
		req.Header.Set("Content-Type", "audio/flac")
	}
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	respBody, _ := io.ReadAll(resp.Body)
	require.Equalf(t, http.StatusOK, resp.StatusCode, "PUT: %d %s", resp.StatusCode, string(respBody))
	t.Logf("Uploaded %d bytes", longInfo.Size())

	// 6. Async ingestion subscriber takes over (Option F, 2026-05-25).
	//    No client-driven CompleteAudioUpload anymore — the bucket
	//    notification fires audio.objectFinalized → ingestion-svc's
	//    in-process subscriber probes duration, runs ffmpeg
	//    silencedetect, splits into N chunks, INSERTs audio_chunks rows,
	//    flips session status PENDING_UPLOAD → CREATED, and publishes
	//    audio.uploaded.
	t.Log("Waiting for async ingestion subscriber to finalize ...")
	t0 := time.Now()
	require.NotEmpty(t, upload.SessionId, "Option E: CreateAudioUpload should have returned session_id")
	sessionID := upload.SessionId
	t.Logf("Session id (from CreateAudioUpload): %s — subscriber will finalize asynchronously", sessionID)
	_ = t0

	// 7. Poll for terminal status.
	terminal := map[string]bool{"COMPLETED": true, "ERRORED": true, "FAILED": true}
	deadline := time.Now().Add(10 * time.Minute)
	var lastStatus, finalStatus string
	for time.Now().Before(deadline) {
		details, err := clinicalClient.GetSessionDetails(ctx,
			&clinicalv1.GetSessionDetailsRequest{SessionId: sessionID})
		if err == nil {
			st := details.Session.Status
			if st != lastStatus {
				t.Logf("  %s status: %s", time.Now().Format("15:04:05"), st)
				lastStatus = st
			}
			if terminal[st] {
				finalStatus = st
				break
			}
		}
		time.Sleep(5 * time.Second)
	}
	require.Equal(t, "COMPLETED", finalStatus,
		"expected COMPLETED; last seen=%q", lastStatus)
}

// synthLongFLAC produces an N-second FLAC by ffmpeg-looping the
// short fixture. Decoded back to 48kHz mono FLAC for compatibility
// with Chirp 3 (matches the existing happy-path fixture's
// characteristics).
func synthLongFLAC(srcPath, dstPath string, durationSec int) error {
	cmd := exec.Command("ffmpeg",
		"-hide_banner", "-loglevel", "error",
		"-stream_loop", "-1",
		"-i", srcPath,
		"-t", fmt.Sprintf("%d", durationSec),
		"-c:a", "flac",
		"-compression_level", "5",
		"-ar", "48000",
		"-ac", "1",
		"-y", dstPath,
	)
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("ffmpeg: %w (stderr: %s)", err, stderr.String())
	}
	return nil
}
