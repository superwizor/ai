//go:build e2e
// +build e2e

// resumable_upload_test.go — verifies the resumable upload path (docs/26 PR1).
//
// Unlike the single-PUT full_session test, this uploads the audio to the GCS
// resumable session URI returned by CreateAudioUpload, in TWO Content-Range
// chunks, exercises a mid-upload resume() query, and asserts the session
// reaches COMPLETED — i.e. exactly one object/finalize from a chunked upload.
//
// MANUAL / opt-in: skips unless RESUMABLE_E2E=1 AND the e2e config is present.
// Requires the resumable-upload server build deployed to the target env.
//
// Run:
//
//	cd superwizor-backend/tests
//	RESUMABLE_E2E=1 AUDIO_FILE=/path/to/sample.flac \
//	  go test -tags=e2e -timeout=20m -v ./e2e/... -run TestResumableUpload
package e2e_test

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"regexp"
	"strconv"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

func TestResumableUpload(t *testing.T) {
	if os.Getenv("RESUMABLE_E2E") == "" {
		t.Skip("RESUMABLE_E2E not set — resumable upload e2e skipped")
	}
	cfg := loadConfig(t)
	audioPath := cfg.audioFile
	if v := os.Getenv("AUDIO_FILE"); v != "" {
		audioPath = v
	}
	require.NotEmpty(t, audioPath, "AUDIO_FILE / cfg.audioFile required")
	audio, err := os.ReadFile(audioPath)
	require.NoError(t, err)
	total := len(audio)
	require.Greater(t, total, 1, "need a non-trivial audio file to split")

	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_uid_resumable_%d", runID)
	firebaseEmail := fmt.Sprintf("test_resumable_%d@example.com", runID)

	idToken := cfg.preMintedToken
	if idToken == "" {
		tctx, tcancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer tcancel()
		fb, ferr := mintFirebaseSession(tctx, cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
		require.NoError(t, ferr)
		t.Cleanup(func() { _ = fb.cleanup() })
		idToken = fb.IDToken
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

	ctx, cancel := context.WithTimeout(context.Background(), 18*time.Minute)
	defer cancel()

	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid: firebaseUID, Email: firebaseEmail,
		Role: identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName: "E2E", LastName: "Resumable",
		UiLanguage: "pl", Timezone: "Europe/Warsaw", HasAcceptedTos: true,
	})
	require.NoError(t, err)

	_, err = clinicalClient.ListModalities(ctx, &emptypb.Empty{})
	require.NoError(t, err)

	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId: therapist.Id, ModalityCode: "CBT",
		WorkingAlias:        fmt.Sprintf("Resumable %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "resumable e2e",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-resumable-pat-%d", runID),
		PatientFirstName:    "Res", PatientLastName: "Umable",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err)
	t.Cleanup(func() {
		bg, bgc := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgc()
		_, _ = clinicalClient.DeletePatientFile(bg, &clinicalv1.DeletePatientFileRequest{PatientFileId: patient.Id})
	})

	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId: therapist.Id, PatientFileId: patient.Id,
		ContentType:        "audio/flac",
		EstimatedSizeBytes: int64(total),
		IdempotencyKey:     fmt.Sprintf("e2e-resumable-up-%d", runID),
		ClientPlatform:     "test",
	})
	require.NoError(t, err)
	require.NotEmpty(t, upload.SessionId)
	require.NotEmpty(t, upload.ResumableSessionUri,
		"server must return a resumable_session_uri (PR1 deployed?)")
	sessionURI := upload.ResumableSessionUri
	t.Logf("session_id=%s resumable_uri=<redacted> total=%d", upload.SessionId, total)

	// resume() before any upload — GCS should report nothing held yet.
	off := resumableQueryOffset(t, sessionURI, total)
	require.Equal(t, 0, off, "fresh session should hold 0 bytes")

	// Upload in two Content-Range chunks. Use a 256 KiB-aligned split.
	const quantum = 256 * 1024
	mid := (total / 2 / quantum) * quantum
	if mid == 0 || mid >= total {
		mid = total / 2
	}
	// chunk 1: [0, mid) → expect 308
	status1 := putRange(t, sessionURI, audio[:mid], 0, total)
	require.Equal(t, http.StatusPermanentRedirect, status1, "first chunk → 308 Resume Incomplete")

	// resume() mid-upload — GCS should report `mid` bytes held.
	require.Equal(t, mid, resumableQueryOffset(t, sessionURI, total), "offset after chunk 1")

	// chunk 2: [mid, total) → expect 200/201 (object finalized exactly once)
	status2 := putRange(t, sessionURI, audio[mid:], mid, total)
	require.Truef(t, status2 == http.StatusOK || status2 == http.StatusCreated,
		"final chunk → 200/201, got %d", status2)

	// Poll to terminal.
	terminal := map[string]bool{"COMPLETED": true, "ERRORED": true, "FAILED": true}
	deadline := time.Now().Add(15 * time.Minute)
	var last, final string
	for time.Now().Before(deadline) {
		d, derr := clinicalClient.GetSessionDetails(ctx, &clinicalv1.GetSessionDetailsRequest{SessionId: upload.SessionId})
		if derr == nil {
			if d.Session.Status != last {
				t.Logf("  %s status: %s", time.Now().Format("15:04:05"), d.Session.Status)
				last = d.Session.Status
			}
			if terminal[d.Session.Status] {
				final = d.Session.Status
				break
			}
		}
		time.Sleep(5 * time.Second)
	}
	require.Equal(t, "COMPLETED", final, "resumable chunked upload must reach COMPLETED; last=%q", last)
	t.Logf("✓ resumable chunked upload COMPLETED")
}

// resumableQueryOffset issues a `Content-Range: bytes */total` query and returns
// the next byte offset GCS holds (0 if none, total if complete).
func resumableQueryOffset(t *testing.T, sessionURI string, total int) int {
	t.Helper()
	req, err := http.NewRequest(http.MethodPut, sessionURI, nil)
	require.NoError(t, err)
	req.Header.Set("Content-Range", fmt.Sprintf("bytes */%d", total))
	req.ContentLength = 0
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	if resp.StatusCode == http.StatusOK || resp.StatusCode == http.StatusCreated {
		return total
	}
	require.Equal(t, http.StatusPermanentRedirect, resp.StatusCode, "resume query → 308")
	return parseResumeOffset(resp.Header.Get("Range"))
}

func putRange(t *testing.T, sessionURI string, chunk []byte, start, total int) int {
	t.Helper()
	end := start + len(chunk) - 1
	req, err := http.NewRequest(http.MethodPut, sessionURI, bytes.NewReader(chunk))
	require.NoError(t, err)
	req.Header.Set("Content-Range", fmt.Sprintf("bytes %d-%d/%d", start, end, total))
	req.ContentLength = int64(len(chunk))
	resp, err := http.DefaultClient.Do(req)
	require.NoError(t, err)
	defer resp.Body.Close()
	_, _ = io.Copy(io.Discard, resp.Body)
	return resp.StatusCode
}

// parseResumeOffset converts GCS "bytes=0-K" → next offset K+1 (0 when absent).
func parseResumeOffset(rangeHeader string) int {
	if rangeHeader == "" {
		return 0
	}
	m := regexp.MustCompile(`bytes=0-(\d+)`).FindStringSubmatch(rangeHeader)
	if m == nil {
		return 0
	}
	n, _ := strconv.Atoi(m[1])
	return n + 1
}
