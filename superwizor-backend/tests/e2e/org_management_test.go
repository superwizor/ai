//go:build e2e

// Org management E2E (docs/38, PR9): provisioning → seat allocations →
// seat-pinned invite → seat limit → per-therapist counters on the debit
// path → deactivation gate → reactivation.
//
// Runs against staging:
//
//	cd superwizor-backend/tests
//	DATABASE_URL=postgres://… go test -tags=e2e -timeout=10m -v ./e2e/ -run TestOrgManagement
//
// Identity RPCs authenticate as FRESH Firebase test users (created and
// deleted by the test — never real accounts). Billing admin RPCs use the
// service-OIDC + x-superwizor-role header path that server-to-server
// callers use (Cloud Run IAM guards invocation). DB access seeds the
// org/user rows and asserts counter state.
package e2e_test

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/stretchr/testify/require"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"google.golang.org/protobuf/types/known/emptypb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	identityv1 "github.com/superwizor-ai/backend/gen/go/identity/v1"
)

func TestOrgManagement_FullFlow(t *testing.T) {
	if os.Getenv("DATABASE_URL") == "" {
		t.Skip("DATABASE_URL not set — org management E2E needs direct DB access")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Minute)
	defer cancel()

	projectID := envOr("GCP_PROJECT_ID", "superwizor-ai-25ecd")
	region := envOr("GCP_REGION", "europe-central2")
	identityURL := os.Getenv("IDENTITY_SVC_URL")
	if identityURL == "" {
		identityURL = describeServiceURL(t, "identity-svc", region, projectID)
	}
	benv := loadBillingEnv(t) // billing URL + OIDC token + db pool
	pool := benv.dbPool

	apiKey := os.Getenv("FIREBASE_API_KEY")
	if apiKey == "" {
		apiKey = autoDetectFirebaseAPIKey(t)
	}
	require.NotEmpty(t, apiKey, "FIREBASE_API_KEY required")

	suffix := strings.ToLower(uuid.NewString()[:8])

	// ── 1. Seed: org + ORG_ADMIN (fresh Firebase test user) + therapist ──
	orgID := mustSeedOrg(t, ctx, pool, "E2E OrgMgmt "+suffix)
	t.Cleanup(func() { cleanupOrg(t, pool, orgID) })

	mgrSession, err := mintFirebaseSession(ctx, projectID, apiKey,
		"e2e-orgmgr-"+suffix, "e2e-orgmgr-"+suffix+"@example.com")
	require.NoError(t, err, "mint manager firebase session")
	t.Cleanup(func() { _ = mgrSession.cleanup() })
	mgrID := mustSeedUser(t, ctx, pool, orgID, mgrSession.UID, mgrSession.Email, "ORG_ADMIN")

	thSession, err := mintFirebaseSession(ctx, projectID, apiKey,
		"e2e-orgth-"+suffix, "e2e-orgth-"+suffix+"@example.com")
	require.NoError(t, err, "mint therapist firebase session")
	t.Cleanup(func() { _ = thSession.cleanup() })
	therapistID := mustSeedUser(t, ctx, pool, orgID, thSession.UID, thSession.Email, "THERAPIST")

	t.Logf("seeded org=%s manager=%s therapist=%s", orgID, mgrID, therapistID)

	// ── 2. AdminSetSeatAllocations (service OIDC + admin headers) ──
	billingConn := dial(t, benv.billingURL, benv.idToken)
	defer billingConn.Close()
	billing := billingv1.NewBillingServiceClient(billingConn)

	adminCtx := metadata.AppendToOutgoingContext(ctx,
		"x-superwizor-role", "SUPERWIZOR_ADMIN")

	var soloPlanID uuid.UUID
	var tokensPerSeat int32
	require.NoError(t, pool.QueryRow(ctx, `
		SELECT id, tokens_per_period FROM subscription_plans
		WHERE is_active = TRUE ORDER BY tokens_per_period DESC LIMIT 1`).
		Scan(&soloPlanID, &tokensPerSeat), "pick a plan")

	summary, err := billing.AdminSetSeatAllocations(adminCtx, &billingv1.AdminSetSeatAllocationsRequest{
		OrganizationId: orgID.String(),
		Allocations: []*billingv1.SeatAllocationSpec{
			{PlanId: soloPlanID.String(), Seats: 2, PriceGrossPerSeat: "79.99"},
		},
		Reason: "E2E org management provisioning " + suffix,
	})
	require.NoError(t, err, "AdminSetSeatAllocations")
	require.Len(t, summary.Allocations, 1)
	require.EqualValues(t, 2, summary.Allocations[0].Seats)
	allocationID := summary.Allocations[0].AllocationId
	t.Logf("✓ allocation %s: 2 seats @79.99, MANUAL sub status=%s", allocationID, summary.SubscriptionStatus)

	// MANUAL b2b subscription exists.
	var subID uuid.UUID
	require.NoError(t, pool.QueryRow(ctx, `
		SELECT id FROM subscriptions
		WHERE organization_id = $1 AND provider = 'MANUAL' AND status = 'ACTIVE'`, orgID).
		Scan(&subID), "b2b subscription created")

	// ── 3. Therapist occupies a seat (as AcceptInvitation would) ──
	_, err = pool.Exec(ctx, `
		INSERT INTO seat_assignments (user_id, allocation_id) VALUES ($1, $2)`,
		therapistID, allocationID)
	require.NoError(t, err, "seed seat assignment")

	// ── 4. Seat-pinned invites via identity as ORG_ADMIN ──
	idConn := dial(t, identityURL, mgrSession.IDToken)
	defer idConn.Close()
	identity := identityv1.NewIdentityServiceClient(idConn)

	inv, err := identity.InviteTherapist(ctx, &identityv1.InviteTherapistRequest{
		Email:        "e2e-invitee-" + suffix + "@example.com",
		FirstName:    "Ewa",
		LastName:     "Testowa",
		AllocationId: allocationID,
	})
	require.NoError(t, err, "invite into free seat")
	require.Equal(t, identityv1.UserRole_USER_ROLE_THERAPIST, inv.InvitedRole)
	t.Logf("✓ invite reserved the 2nd seat (invitation %s)", inv.Id)

	// Occupancy now 2/2 (1 assignment + 1 pending invite) → next invite fails.
	_, err = identity.InviteTherapist(ctx, &identityv1.InviteTherapistRequest{
		Email:        "e2e-overflow-" + suffix + "@example.com",
		AllocationId: allocationID,
	})
	require.Error(t, err, "3rd seat must not exist")
	st, _ := status.FromError(err)
	require.Equal(t, codes.FailedPrecondition, st.Code())
	require.Contains(t, st.Message(), "SEATS_EXHAUSTED")
	t.Logf("✓ SEATS_EXHAUSTED on overbooking (2/2 incl. pending invite)")

	// ── 5. Per-therapist counters on the debit path ──
	sessionID := uuid.New()
	res, err := billing.ReserveCredit(adminCtx, &billingv1.ReserveCreditRequest{
		SessionId:      sessionID.String(),
		OrganizationId: orgID.String(),
		TherapistId:    therapistID.String(),
	})
	require.NoError(t, err, "ReserveCredit for seated therapist")
	require.EqualValues(t, 1, res.TokensReserved)

	var counterTherapist uuid.UUID
	var reserved int32
	require.NoError(t, pool.QueryRow(ctx, `
		SELECT therapist_id, tokens_reserved FROM usage_counters
		WHERE subscription_id = $1 AND therapist_id IS NOT NULL`, subID).
		Scan(&counterTherapist, &reserved), "lazy-minted per-therapist counter")
	require.Equal(t, therapistID, counterTherapist, "counter belongs to the caller")
	require.EqualValues(t, 1, reserved)

	var resTherapist uuid.UUID
	require.NoError(t, pool.QueryRow(ctx, `
		SELECT therapist_id FROM pending_reservations WHERE session_id = $1`, sessionID).
		Scan(&resTherapist), "reservation records the debited scope")
	require.Equal(t, therapistID, resTherapist)
	t.Logf("✓ ReserveCredit lazily minted the therapist counter and recorded scope")

	_, err = billing.CommitUsage(adminCtx, &billingv1.CommitUsageRequest{
		SessionId:      sessionID.String(),
		OrganizationId: orgID.String(),
		TherapistId:    therapistID.String(),
		DurationSeconds: 600,
	})
	require.NoError(t, err, "CommitUsage")
	var used int32
	require.NoError(t, pool.QueryRow(ctx, `
		SELECT tokens_used FROM usage_counters
		WHERE subscription_id = $1 AND therapist_id = $2`, subID, therapistID).
		Scan(&used))
	require.EqualValues(t, 1, used, "commit lands on the SAME therapist counter")
	t.Logf("✓ CommitUsage debited the therapist's own counter (used=%d)", used)

	// ── 6. GetMyOrgSeatUsage as ORG_ADMIN ──
	orgCtx := metadata.AppendToOutgoingContext(ctx,
		"x-superwizor-role", "ORG_ADMIN",
		"x-superwizor-organization-id", orgID.String())
	usage, err := billing.GetMyOrgSeatUsage(orgCtx, &emptypb.Empty{})
	require.NoError(t, err, "GetMyOrgSeatUsage")
	require.Len(t, usage.Allocations, 1)
	require.EqualValues(t, 1, usage.Allocations[0].SeatsAssigned)
	require.EqualValues(t, 1, usage.Allocations[0].SeatsPending)
	require.NotEmpty(t, usage.TherapistUsage, "per-therapist usage visible")
	t.Logf("✓ GetMyOrgSeatUsage: 1 assigned + 1 pending, %d usage rows", len(usage.TherapistUsage))

	// ── 7. Deactivation frees the seat and blocks the account ──
	deactivated, err := identity.SetTherapistStatus(ctx, &identityv1.SetTherapistStatusRequest{
		UserId:   therapistID.String(),
		IsActive: false,
	})
	require.NoError(t, err, "SetTherapistStatus deactivate")
	require.False(t, deactivated.IsActive)

	var unassigned bool
	require.NoError(t, pool.QueryRow(ctx, `
		SELECT unassigned_at IS NOT NULL FROM seat_assignments
		WHERE user_id = $1 ORDER BY assigned_at DESC LIMIT 1`, therapistID).
		Scan(&unassigned))
	require.True(t, unassigned, "deactivation must free the seat")

	_, err = identity.ValidateToken(ctx, &identityv1.ValidateTokenRequest{
		FirebaseIdToken: thSession.IDToken,
	})
	require.Error(t, err, "deactivated account must not validate")
	st, _ = status.FromError(err)
	require.Equal(t, codes.PermissionDenied, st.Code())
	require.Contains(t, st.Message(), "ACCOUNT_DEACTIVATED")
	t.Logf("✓ deactivation: seat freed + ValidateToken → ACCOUNT_DEACTIVATED")

	// ── 8. Reactivation re-occupies a seat ──
	reactivated, err := identity.SetTherapistStatus(ctx, &identityv1.SetTherapistStatusRequest{
		UserId:   therapistID.String(),
		IsActive: true,
	})
	require.NoError(t, err, "SetTherapistStatus reactivate (a seat is free)")
	require.True(t, reactivated.IsActive)

	_, err = identity.ValidateToken(ctx, &identityv1.ValidateTokenRequest{
		FirebaseIdToken: thSession.IDToken,
	})
	require.NoError(t, err, "reactivated account validates again")
	t.Logf("✓ reactivation restores access")
}

// ── seeding helpers ──────────────────────────────────────────────────

func mustSeedOrg(t *testing.T, ctx context.Context, pool *pgxpool.Pool, name string) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(ctx, `
		INSERT INTO organizations (legal_name, type) VALUES ($1, 'CLINIC')
		RETURNING id`, name).Scan(&id))
	return id
}

func mustSeedUser(t *testing.T, ctx context.Context, pool *pgxpool.Pool, orgID uuid.UUID, fbUID, email, role string) uuid.UUID {
	t.Helper()
	var id uuid.UUID
	require.NoError(t, pool.QueryRow(ctx, `
		INSERT INTO users (role, organization_id, firebase_uid, email,
		                   first_name, last_name, has_accepted_tos)
		VALUES ($1, $2, $3, $4, 'E2E', 'OrgMgmt', TRUE)
		RETURNING id`, role, orgID, fbUID, email).Scan(&id))
	return id
}

// cleanupOrg removes everything the test created, child-first. Best
// effort — a failed cleanup logs but doesn't fail the test.
func cleanupOrg(t *testing.T, pool *pgxpool.Pool, orgID uuid.UUID) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	stmts := []string{
		`DELETE FROM pending_reservations WHERE organization_id = $1`,
		`DELETE FROM usage_events WHERE organization_id = $1`,
		`DELETE FROM usage_counters WHERE subscription_id IN
		   (SELECT id FROM subscriptions WHERE organization_id = $1)`,
		`DELETE FROM subscriptions WHERE organization_id = $1`,
		`DELETE FROM seat_assignments WHERE allocation_id IN
		   (SELECT id FROM org_seat_allocations WHERE organization_id = $1)`,
		`DELETE FROM invitations WHERE organization_id = $1`,
		`DELETE FROM org_seat_allocations WHERE organization_id = $1`,
		`DELETE FROM audit_events WHERE organization_id = $1`,
		`DELETE FROM users WHERE organization_id = $1`,
		`DELETE FROM organizations WHERE id = $1`,
	}
	for _, s := range stmts {
		if _, err := pool.Exec(ctx, s, orgID); err != nil {
			t.Logf("cleanup: %s: %v", strings.Fields(s)[2], err)
		}
	}
	fmt.Println("org-management e2e cleanup done for", orgID)
}
