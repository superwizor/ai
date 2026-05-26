//go:build e2e
// +build e2e

package e2e_test

import (
	"context"
	"fmt"
	"os"
	"testing"
	"time"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
	"github.com/stretchr/testify/require"
)

// TestVerifyMarcinSession verifies that the canonical-blob fix in clinical-svc
// GetSessionDetails returns transcript + reports for Marcin's 107-minute
// session (020a2616-4f9b-43d0-87ec-e37d7bcac2be).
//
// Before the fix: the per-segment KMS decrypt loop did 1182 KMS round-trips
// (~100ms each = ~118s) which blew past the 30s gRPC deadline → empty response.
//
// After the fix: 1 KMS call + JSON unmarshal → ~150ms total.
//
// Run with:
//
//	go test ./tests/e2e -run TestVerifyMarcinSession -v -timeout 60s
func TestVerifyMarcinSession(t *testing.T) {
	if os.Getenv("VERIFY_MARCIN") == "" {
		t.Skip("set VERIFY_MARCIN=1 to run")
	}

	cfg := loadConfig(t)
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("verify_marcin_%d", runID)
	firebaseEmail := fmt.Sprintf("verify_marcin_%d@example.com", runID)

	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()

	t.Logf("Minting Firebase ID token for uid=%s ...", firebaseUID)
	fbSession, err := mintFirebaseSession(tokenCtx, cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
	require.NoError(t, err, "mint Firebase session")
	t.Cleanup(func() { _ = fbSession.cleanup() })

	// Register the user via identity-svc so clinical-svc's auth interceptor
	// (which calls identity-svc.ValidateToken) can resolve the Firebase UID
	// → users row. Without this we get "user not registered".
	identityConn := dial(t, cfg.identityURL, fbSession.IDToken)
	defer identityConn.Close()
	identityClient := identityv1.NewIdentityServiceClient(identityConn)

	regCtx, regCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer regCancel()
	_, err = identityClient.CreateUser(regCtx, &identityv1.CreateUserRequest{
		FirebaseUid:    firebaseUID,
		Email:          firebaseEmail,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName:      "Verify",
		LastName:       "Marcin",
		UiLanguage:     "pl",
		Timezone:       "Europe/Warsaw",
		HasAcceptedTos: true,
	})
	require.NoError(t, err, "register user in identity-svc")

	conn := dial(t, cfg.clinicalURL, fbSession.IDToken)
	defer conn.Close()

	client := clinicalv1.NewClinicalServiceClient(conn)
	const sessionID = "020a2616-4f9b-43d0-87ec-e37d7bcac2be"

	callCtx, callCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer callCancel()

	start := time.Now()
	resp, err := client.GetSessionDetails(callCtx, &clinicalv1.GetSessionDetailsRequest{
		SessionId: sessionID,
	})
	elapsed := time.Since(start)

	require.NoError(t, err, "GetSessionDetails should not error after canonical-blob fix")
	require.NotNil(t, resp.Session, "session present")
	require.NotNil(t, resp.Transcript, "transcript present (canonical blob path returned segments)")

	t.Logf("✓ GetSessionDetails returned in %s", elapsed)
	t.Logf("  session.id=%s status=%s duration=%ds",
		resp.Session.Id, resp.Session.Status, resp.Session.DurationSeconds)
	t.Logf("  transcript.id=%s segments=%d turns=%d",
		resp.Transcript.Id, len(resp.Transcript.Segments), len(resp.Transcript.Turns))
	t.Logf("  reports=%d", len(resp.Reports))

	require.Greater(t, len(resp.Transcript.Segments), 1000,
		"expected ~1182 segments after canonical decode")
	require.GreaterOrEqual(t, len(resp.Reports), 1, "at least one report")

	if elapsed > 10*time.Second {
		t.Logf("⚠ latency %s is higher than expected (<2s) — canonical path may have fallen back to per-segment", elapsed)
	}
}
