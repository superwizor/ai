//go:build e2e
// +build e2e

package e2e_test

// ordering_gate_test.go — e2e for the per-patient-file ordering gate
// (docs/40_STT_ORDERING_GATE.md). Uploads TWO sessions of the SAME
// patient file back-to-back (no waiting between PUTs) and asserts the
// pipeline serializes them: session 2 must not enter TRANSCRIBING while
// session 1 is still non-terminal, and both must end COMPLETED in order.
//
// Requires STT_ORDER_GATE=on on the deployed stt-worker; when the gate
// is off the serialization assertion is skipped (the test then only
// checks both sessions complete) so the suite stays green pre-rollout —
// controlled via the ORDER_GATE_E2E env var:
//
//	ORDER_GATE_E2E=strict  → fail if serialization is violated
//	unset / anything else  → observe + log only

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

// uploadSessionNoWait creates the upload and PUTs the fixture but does
// NOT wait for processing — returns the session id immediately.
func uploadSessionNoWait(t *testing.T, ctx context.Context, cfg config,
	ingestionClient ingestionv1.IngestionServiceClient,
	therapistID, patientID, idemKey string, audioSize int64) string {
	t.Helper()

	upload, err := ingestionClient.CreateAudioUpload(ctx, &ingestionv1.CreateAudioUploadRequest{
		TherapistId:              therapistID,
		PatientFileId:            patientID,
		ContentType:              "audio/flac",
		EstimatedSizeBytes:       audioSize,
		EstimatedDurationSeconds: 0,
		IdempotencyKey:           idemKey,
		ClientAppVersion:         "e2e-ordergate-1.0",
		ClientPlatform:           "test",
	})
	require.NoError(t, err, "CreateAudioUpload")
	require.NotEmpty(t, upload.SessionId)

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
	return upload.SessionId
}

func TestOrderingGate_TwoConcurrentSessions(t *testing.T) {
	cfg := loadConfig(t)
	strict := os.Getenv("ORDER_GATE_E2E") == "strict"
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("test_gate_uid_%d", runID)
	firebaseEmail := fmt.Sprintf("test_gate_%d@example.com", runID)

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

	// Both sessions run mostly serialized end-to-end; the gate adds up to
	// one redelivery backoff (≤600 s) between them.
	ctx, cancel := context.WithTimeout(context.Background(), 2*cfg.pollDeadline+12*time.Minute)
	defer cancel()

	therapist, err := identityClient.CreateUser(ctx, &identityv1.CreateUserRequest{
		FirebaseUid:    firebaseUID,
		Email:          firebaseEmail,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName:      "E2E",
		LastName:       "GateTherapist",
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
		WorkingAlias:        fmt.Sprintf("E2E Gate Patient %d", runID),
		ProcessType:         clinicalv1.ProcessType_PROCESS_TYPE_INDIVIDUAL,
		InitialComplaint:    "E2E ordering gate test",
		HasRecordingConsent: true,
		IdempotencyKey:      fmt.Sprintf("e2e-gate-patient-%d", runID),
		PatientFirstName:    "E2E",
		PatientLastName:     "GatePatient",
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

	t.Log("═══ Uploading session 1 and session 2 back-to-back (no wait) ═══")
	sess1 := uploadSessionNoWait(t, ctx, cfg, ingestionClient, therapist.Id, patient.Id,
		fmt.Sprintf("e2e-gate-up1-%d", runID), audioSize)
	sess2 := uploadSessionNoWait(t, ctx, cfg, ingestionClient, therapist.Id, patient.Id,
		fmt.Sprintf("e2e-gate-up2-%d", runID), audioSize)
	t.Logf("sess1=%s sess2=%s", sess1, sess2)

	// Poll both until terminal, recording every observed status pair.
	// Serialization invariant: whenever sess1 is non-terminal, sess2 must
	// still be in a pre-pipeline status (PENDING_UPLOAD or CREATED).
	prePipeline := map[string]bool{"PENDING_UPLOAD": true, "CREATED": true, "": true}
	terminal := map[string]bool{"COMPLETED": true, "FAILED": true, "ERRORED": true, "CANCELLED_BY_USER": true}

	status := func(id string) string {
		d, derr := clinicalClient.GetSessionDetails(ctx, &clinicalv1.GetSessionDetailsRequest{SessionId: id})
		if derr != nil || d == nil || d.Session == nil {
			return ""
		}
		return d.Session.Status
	}

	var s1Done time.Time
	var violations []string
	var last1, last2 string
	deadline := time.Now().Add(2*cfg.pollDeadline + 11*time.Minute)
	for time.Now().Before(deadline) {
		s1, s2 := status(sess1), status(sess2)
		if s1 != last1 || s2 != last2 {
			t.Logf("  %s sess1=%s sess2=%s", time.Now().Format("15:04:05"), s1, s2)
			last1, last2 = s1, s2
		}
		if !terminal[s1] && !prePipeline[s2] {
			violations = append(violations,
				fmt.Sprintf("sess2=%s while sess1=%s (non-terminal)", s2, s1))
		}
		if terminal[s1] && s1Done.IsZero() {
			s1Done = time.Now()
		}
		if terminal[s1] && terminal[s2] {
			break
		}
		select {
		case <-ctx.Done():
			t.Fatalf("context canceled: %v", ctx.Err())
		case <-time.After(3 * time.Second):
		}
	}

	require.Equal(t, "COMPLETED", status(sess1), "session 1 must complete")
	require.Equal(t, "COMPLETED", status(sess2), "session 2 must complete")

	if len(violations) > 0 {
		msg := fmt.Sprintf("ordering violated %d time(s); first: %s", len(violations), violations[0])
		if strict {
			t.Fatal(msg)
		}
		t.Logf("⚠ (non-strict) %s — is STT_ORDER_GATE=on on stt-worker?", msg)
	} else {
		t.Log("✓ serialization held: sess2 never entered the pipeline before sess1's terminal status")
	}
}
