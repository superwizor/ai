//go:build e2e
// +build e2e

// manual_long_audio_test.go — operator-driven long-audio regression.
//
// Unlike TestLongSession_Chunked (which synthesises a 22-min FLAC by
// looping a short fixture), this test uploads a REAL long recording you
// point it at and drives it through the full pipeline against staging:
// CreateAudioUpload → PUT → server-side ffmpeg chunking → per-chunk Chirp
// BatchRecognize → stt-finalize merge → llm-worker report → COMPLETED.
//
// Born from session e55b7c1e (2026-06-04): a ~74-min recording whose
// chunk_0 came out 21.0 min and was rejected by Chirp's 20-min
// BatchRecognize limit. Use this to replay any such audio against the
// fixed chunker and confirm every chunk stays under the cap and the
// session COMPLETEs.
//
// MANUAL / opt-in: skips unless LONG_AUDIO_FILE is set, so the normal
// e2e suite and CI are unaffected.
//
// Run:
//
//	cd superwizor-backend/tests
//	LONG_AUDIO_FILE=/path/to/recording.flac \
//	  go test -tags=e2e -timeout=40m -v ./e2e/... -run TestLongSession_Manual
package e2e_test

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

// TestLongSession_Manual uploads the file at LONG_AUDIO_FILE and asserts
// the session reaches COMPLETED with a transcript + report. The deadline
// is generous (dynamic-batch STT has no latency SLA and a 60-90 min
// recording fans out to several chunks).
func TestLongSession_Manual(t *testing.T) {
	audioPath := os.Getenv("LONG_AUDIO_FILE")
	if audioPath == "" {
		t.Skip("LONG_AUDIO_FILE not set — manual long-audio test skipped")
	}
	info, err := os.Stat(audioPath)
	require.NoErrorf(t, err, "LONG_AUDIO_FILE %q not readable", audioPath)

	durSec := probeDurationSec(t, audioPath)
	t.Logf("Long audio: %s — %.1f MB, %.1f min",
		audioPath, float64(info.Size())/1024/1024, float64(durSec)/60)
	if durSec > 0 && durSec < 20*60 {
		t.Logf("WARNING: audio is < 20 min; server-side chunking may not trigger, "+
			"so this won't exercise the multi-chunk cap path (dur=%ds)", durSec)
	}

	cfg := loadConfig(t)

	// Mint a throwaway Firebase user — never touches the real session.
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_uid_manual_%d", runID)
	firebaseEmail := fmt.Sprintf("test_manual_%d@example.com", runID)

	var idToken string
	if cfg.preMintedToken != "" {
		idToken = cfg.preMintedToken
	} else {
		tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer tokenCancel()
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

	ctx, cancel := context.WithTimeout(context.Background(), 38*time.Minute)
	defer cancel()

	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid: firebaseUID, Email: firebaseEmail,
		Role: identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName: "E2E", LastName: "Manual",
		UiLanguage: "pl", Timezone: "Europe/Warsaw", HasAcceptedTos: true,
	})
	require.NoError(t, err)

	mods, err := clinicalClient.ListModalities(ctx, &emptypb.Empty{})
	require.NoError(t, err)
	require.NotEmpty(t, mods.Modalities)

	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId: therapist.Id, ModalityCode: "CBT",
		WorkingAlias:        fmt.Sprintf("Manual Long %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "manual long-audio e2e",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-manual-pat-%d", runID),
		PatientFirstName:    "Manual", PatientLastName: "Patient",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		bg, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, _ = clinicalClient.DeletePatientFile(bg,
			&clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
	})

	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId: therapist.Id, PatientFileId: patient.Id,
		ContentType:              "audio/flac",
		EstimatedSizeBytes:       info.Size(),
		EstimatedDurationSeconds: int32(durSec),
		IdempotencyKey:           fmt.Sprintf("e2e-manual-up-%d", runID),
		ClientAppVersion:         "e2e-manual-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err)
	require.NotEmpty(t, upload.SessionId, "CreateAudioUpload should return session_id")
	t.Logf("upload_id=%s session_id=%s", upload.UploadId, upload.SessionId)

	body, err := os.ReadFile(audioPath)
	require.NoError(t, err)
	putReq, err := http.NewRequestWithContext(ctx, http.MethodPut, upload.SignedUrl, bytes.NewReader(body))
	require.NoError(t, err)
	for k, v := range upload.RequiredHeaders {
		putReq.Header.Set(k, v)
	}
	if putReq.Header.Get("x-goog-meta-source") == "" {
		putReq.Header.Set("x-goog-meta-source", "superwizor-mobile")
	}
	if putReq.Header.Get("Content-Type") == "" {
		putReq.Header.Set("Content-Type", "audio/flac")
	}
	putResp, err := http.DefaultClient.Do(putReq)
	require.NoError(t, err)
	defer putResp.Body.Close()
	putBody, _ := io.ReadAll(putResp.Body)
	require.Equalf(t, http.StatusOK, putResp.StatusCode, "PUT: %d %s", putResp.StatusCode, string(putBody))
	t.Logf("uploaded %d bytes; async ingestion + chunking takes over", info.Size())

	// Poll to terminal. 35-min budget: chunking + N× dynamic-batch STT
	// (no SLA) + finalize + report.
	terminal := map[string]bool{"COMPLETED": true, "ERRORED": true, "FAILED": true}
	deadline := time.Now().Add(35 * time.Minute)
	var lastStatus, finalStatus string
	for time.Now().Before(deadline) {
		details, derr := clinicalClient.GetSessionDetails(ctx,
			&clinicalv1.GetSessionDetailsRequest{SessionId: upload.SessionId})
		if derr == nil {
			st := details.Session.Status
			if st != lastStatus {
				t.Logf("  %s status: %s", time.Now().Format("15:04:05"), st)
				lastStatus = st
			}
			if terminal[st] {
				finalStatus = st
				if st == "COMPLETED" {
					require.NotEmpty(t, details.Reports,
						"COMPLETED session must carry a report")
				}
				break
			}
		}
		time.Sleep(5 * time.Second)
	}
	require.Equalf(t, "COMPLETED", finalStatus,
		"long audio must reach COMPLETED (not FAILED on an oversized chunk); last=%q", lastStatus)
	t.Logf("✓ long audio COMPLETED — every chunk stayed under Chirp's 20-min cap")
}

// probeDurationSec returns the audio duration in seconds via ffprobe, or
// 0 if ffprobe is unavailable / fails (the test still runs).
func probeDurationSec(t *testing.T, path string) int {
	t.Helper()
	out, err := exec.Command("ffprobe", "-v", "error",
		"-show_entries", "format=duration", "-of", "default=nk=1:nw=1", path).Output()
	if err != nil {
		t.Logf("ffprobe unavailable (%v) — skipping duration check", err)
		return 0
	}
	f, perr := strconv.ParseFloat(strings.TrimSpace(string(out)), 64)
	if perr != nil {
		return 0
	}
	return int(f)
}
