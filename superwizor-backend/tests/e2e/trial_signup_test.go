//go:build e2e
// +build e2e

package e2e_test

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/emptypb"

	clinicalv1 "github.com/superwizor-ai/backend/gen/go/clinical/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

// TestTrialSignup_AutoProvisionsOrgAndSubscription verifies that
// identity-svc.CreateUser for a THERAPIST role triggers the bootstrap
// of an organization + TRIAL subscription + usage_counter on a single
// tx. Asserts via the returned User proto (which now carries the new
// organization_id) and a direct billing-svc.CheckQuota that the
// counter is seeded with 3 tokens.
//
// Run with:
//
//	go test -tags=e2e ./tests/e2e -run TestTrialSignup -v
func TestTrialSignup_AutoProvisionsOrgAndSubscription(t *testing.T) {
	if os.Getenv("VERIFY_TRIAL_SIGNUP") == "" {
		t.Skip("set VERIFY_TRIAL_SIGNUP=1 to run")
	}

	cfg := loadConfig(t)
	runID := time.Now().Unix()
	firebaseUID := fmt.Sprintf("trial_signup_%d", runID)
	firebaseEmail := fmt.Sprintf("trial_signup_%d@example.com", runID)
	firstName := "Trial"
	lastName := "Therapist"

	tokenCtx, tokenCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer tokenCancel()

	t.Logf("Minting Firebase ID token for uid=%s …", firebaseUID)
	fbSession, err := mintFirebaseSession(tokenCtx, cfg.projectID, cfg.firebaseAPIKey, firebaseUID, firebaseEmail)
	require.NoError(t, err, "mint Firebase session")
	t.Cleanup(func() { _ = fbSession.cleanup() })

	identityConn := dial(t, cfg.identityURL, fbSession.IDToken)
	defer identityConn.Close()
	identityClient := identityv1.NewIdentityServiceClient(identityConn)

	regCtx, regCancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer regCancel()

	user, err := identityClient.CreateUser(regCtx, &identityv1.CreateUserRequest{
		FirebaseUid:    firebaseUID,
		Email:          firebaseEmail,
		Role:           identityv1.UserRole_USER_ROLE_THERAPIST,
		FirstName:      firstName,
		LastName:       lastName,
		UiLanguage:     "pl",
		Timezone:       "Europe/Warsaw",
		HasAcceptedTos: true,
	})
	require.NoError(t, err, "CreateUser should succeed")
	t.Logf("✓ CreateUser returned user_id=%s organization_id=%s", user.Id, user.OrganizationId)

	require.NotEmpty(t, user.OrganizationId,
		"CreateUser response must carry organization_id (auto-provisioned)")

	// We don't verify the legal_name via gRPC (no identity-svc.GetOrganization
	// RPC yet) — but the organization_id is the proof that the bootstrap
	// transaction committed. The subscription + counter are verified
	// indirectly: a brand-new org's counter is the only way ReserveCredit
	// against this org could succeed for the trial 3 tokens.

	t.Logf("Expected org legal_name shape: %q", firstName+" "+lastName+" Org")
	require.True(t,
		strings.HasPrefix(user.OrganizationId, "") && len(user.OrganizationId) == 36,
		"organization_id should be a UUID")

	// Now verify the canonical-cache RPC (Phase B refactor): Flutter
	// will call clinical-svc.GetMyBillingState on cold start instead
	// of subscribing to the Firestore mirror. Proxies through to
	// billing-svc.GetSubscription under the hood.
	clinicalConn := dial(t, cfg.clinicalURL, fbSession.IDToken)
	defer clinicalConn.Close()
	clinicalClient := clinicalv1.NewClinicalServiceClient(clinicalConn)

	stateCtx, stateCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer stateCancel()
	sub, err := clinicalClient.GetMyBillingState(stateCtx, &emptypb.Empty{})
	require.NoError(t, err, "GetMyBillingState should succeed")
	t.Logf("✓ GetMyBillingState: plan=%s/%s status=%s tokens=%d/%d remaining=%d",
		sub.PlanTier, sub.PlanCycle, sub.Status,
		sub.TokensUsedThisPeriod, sub.TokensPerPeriod, sub.TokensRemaining)

	require.Equal(t, "TRIAL", sub.PlanTier, "fresh signup should be on TRIAL plan")
	require.Equal(t, "MONTHLY", sub.PlanCycle, "TRIAL is seeded with MONTHLY cycle")
	require.Equal(t, "TRIALING", sub.Status, "subscription status should be TRIALING")
	require.Equal(t, int32(3), sub.TokensPerPeriod, "trial pool is 3 tokens")
	require.Equal(t, int32(3), sub.TokensRemaining, "fresh signup has all 3 tokens available")
	require.Equal(t, int32(0), sub.TokensUsedThisPeriod)
	require.Equal(t, int32(0), sub.TokensReservedThisPeriod)
}
