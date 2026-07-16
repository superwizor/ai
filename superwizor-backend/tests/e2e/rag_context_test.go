//go:build e2e
// +build e2e

package e2e_test

// rag_context_test.go — two-session RAG verification (docs/30 Phase 4).
//
// Runs TWO full pipeline sessions for the SAME patient. Session 1 seeds
// rag_memories (summary + theme rows via persistRAGMemoryV2); session 2's
// llm-worker run must then retrieve a non-empty prior-session context via
// loadRAGContextV2 (pool from session 1, anchor = session 1's summary).
//
// The gRPC surface doesn't expose retrieval internals, so this test
// asserts the user-visible contract (both sessions COMPLETED with valid
// reports + same patient) and prints the session ids; the operator (or CI
// wrapper) confirms the `rag.retrieved` analytics event for session 2 in
// Cloud Logging:
//
//	gcloud logging read 'resource.labels.service_name="llm-worker"
//	  jsonPayload.ae="rag.retrieved" jsonPayload.session_id="<SESSION_2>"'
//
// Expected for session 2: mode=v2, pool_size>0, hits>=1, anchor_used=true.

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
)

// runPipelineSession uploads the fixture as a new session for an existing
// patient and polls until terminal, requiring COMPLETED. Returns session id.
func runPipelineSession(t *testing.T, ctx context.Context, cfg config,
	ingestionClient ingestionv1.IngestionServiceClient,
	clinicalClient clinicalv1.ClinicalServiceClient,
	therapistID, patientID, idemKey string, audioSize int64) string {
	t.Helper()

	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId:              therapistID,
		PatientFileId:            patientID,
		ContentType:              "audio/flac",
		EstimatedSizeBytes:       audioSize,
		EstimatedDurationSeconds: 0, // unknown — a fake value would trip the client-vs-decode anomaly check
		IdempotencyKey:           idemKey,
		ClientAppVersion:         "e2e-rag-test-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err, "CreateAudioUpload")
	require.NotEmpty(t, upload.SessionId, "session_id missing from CreateAudioUploadResponse")

	audioBytes, err := os.ReadFile(cfg.audioFile)
	require.NoError(t, err)
	req, err := http.NewRequestWithContext(ctx, http.MethodPut, upload.SignedUrl, bytes.NewReader(audioBytes))
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
	require.NoError(t, err, "PUT signed URL")
	body, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	require.Equalf(t, http.StatusOK, resp.StatusCode, "PUT returned %d: %s", resp.StatusCode, string(body))
	t.Logf("✓ audio uploaded for session %s", upload.SessionId)

	terminal := map[string]bool{"COMPLETED": true, "ERRORED": true, "FAILED": true}
	deadline := time.Now().Add(cfg.pollDeadline)
	var lastStatus string
	for time.Now().Before(deadline) {
		details, derr := clinicalClient.GetSessionDetails(ctx,
			&clinicalv1.GetSessionDetailsRequest{SessionId: upload.SessionId})
		if derr == nil && details != nil && details.Session != nil {
			if details.Session.Status != lastStatus {
				t.Logf("  %s status: %s", time.Now().Format("15:04:05"), details.Session.Status)
				lastStatus = details.Session.Status
			}
			if terminal[details.Session.Status] {
				require.Equal(t, "COMPLETED", details.Session.Status, "session %s ended %s", upload.SessionId, details.Session.Status)
				require.NotEmpty(t, details.Reports, "COMPLETED session must carry a report")
				return upload.SessionId
			}
		}
		select {
		case <-ctx.Done():
			t.Fatalf("context canceled while polling: %v", ctx.Err())
		case <-time.After(5 * time.Second):
		}
	}
	t.Fatalf("session %s did not reach terminal status within %s (last: %s)", upload.SessionId, cfg.pollDeadline, lastStatus)
	return ""
}

func TestFullSession_RAGTwoSessions(t *testing.T) {
	cfg := loadConfig(t)
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_rag_uid_%d", runID)
	firebaseEmail := fmt.Sprintf("test_rag_%d@example.com", runID)

	audioSize := assertValidAudio(t, cfg.audioFile)

	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()
	var idToken string
	if cfg.preMintedToken != "" {
		idToken = cfg.preMintedToken
	} else {
		fbSession, err := mintFirebaseSession(tokenCtx, cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
		require.NoError(t, err, "Firebase token minting")
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

	// Two pipeline runs back-to-back — double the single-session deadline.
	ctx, cancel := context.WithTimeout(context.Background(), 2*cfg.pollDeadline+2*time.Minute)
	defer cancel()

	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid:    firebaseUID,
		Email:          firebaseEmail,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName:      "E2E",
		LastName:       "RAGTherapist",
		UiLanguage:     "pl",
		Timezone:       "Europe/Warsaw",
		HasAcceptedTos: true,
	})
	require.NoError(t, err, "CreateUser")

	mods, err := clinicalClient.ListModalities(ctx, &emptypb.Empty{})
	require.NoError(t, err)
	require.NotEmpty(t, mods.Modalities)

	patient, err := clinicalClient.CreatePatientFile(ctx, &clinicalv1.CreatePatientFileRequest{
		TherapistId:         therapist.Id,
		ModalityCode:        "CBT",
		WorkingAlias:        fmt.Sprintf("E2E RAG Patient %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "E2E RAG continuity test",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-rag-patient-%d", runID),
		PatientFirstName:    "E2E",
		PatientLastName:     "RAGPatient",
		PatientLanguageCode: "pl",
	})
	require.NoError(t, err, "CreatePatientFile")
	t.Cleanup(func() {
		bgCtx, bgCancel := context.WithTimeout(context.Background(), 30*time.Second)
		defer bgCancel()
		_, _ = clinicalClient.DeletePatientFile(bgCtx, &clinicalv1.DeletePatientFileRequest{
			PatientFileId: patient.Id,
		})
	})

	t.Log("\n═══ Session 1/2 (seeds rag_memories: summary + themes) ═══")
	sess1 := runPipelineSession(t, ctx, cfg, ingestionClient, clinicalClient,
		therapist.Id, patient.Id, fmt.Sprintf("e2e-rag-upload-1-%d", runID), audioSize)

	t.Log("\n═══ Session 2/2 (must retrieve session-1 context) ═══")
	sess2 := runPipelineSession(t, ctx, cfg, ingestionClient, clinicalClient,
		therapist.Id, patient.Id, fmt.Sprintf("e2e-rag-upload-2-%d", runID), audioSize)

	t.Logf("\n══════════════════════════════════════════════════════════════")
	t.Logf("  BOTH SESSIONS COMPLETED — verify retrieval in Cloud Logging:")
	t.Logf("  session_1 (seed):     %s", sess1)
	t.Logf("  session_2 (retrieve): %s", sess2)
	t.Logf("  gcloud logging read 'resource.labels.service_name=\"llm-worker\" jsonPayload.ae=\"rag.retrieved\" jsonPayload.session_id=\"%s\"' --project=%s --freshness=1h", sess2, cfg.projectID)
	t.Logf("  expect: mode=v2 pool_size>0 hits>=1 anchor_used=true")
	t.Logf("══════════════════════════════════════════════════════════════")
}
