package grpc

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// adminCtx builds an incoming-metadata context that resolveAdminCaller
// accepts as a SUPERWIZOR_ADMIN.
func adminCtx() context.Context {
	md := metadata.Pairs(
		"x-superwizor-role", "SUPERWIZOR_ADMIN",
		"x-superwizor-user-id", uuid.New().String(),
	)
	return metadata.NewIncomingContext(context.Background(), md)
}

// TestAdminChangePlan_AuditFailureRollsBack locks the atomicity
// contract that the 2026-05-29 incident depended on: when the audit
// write fails (e.g. audit_events.reason column missing under a
// migration drift), AdminChangePlan must return an error and the
// whole tx — the plan flip + counter-limit update — must roll back.
// If this ever regresses, a failed admin upgrade could half-apply
// (plan changed, no audit), leaving billing in a split-brain state.
func TestAdminChangePlan_AuditFailureRollsBack(t *testing.T) {
	q := &fakeQuerier{}
	sub := subRow(t, db.SubscriptionStatusTRIALING, 3)
	q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
		return sub, nil
	}
	q.adminGetPlanFn = func(ctx context.Context, _ db.AdminGetPlanByTierCycleParams) (db.SubscriptionPlan, error) {
		return db.SubscriptionPlan{ID: uuid.New(), TokensPerPeriod: 20}, nil
	}
	q.adminChangePlanFn = func(ctx context.Context, _ db.AdminChangeSubscriptionPlanParams) (db.Subscription, error) {
		return db.Subscription{}, nil
	}
	q.lockActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
		return counterRow(3, 0, 3), nil
	}
	q.adminUpdateCounterFn = func(ctx context.Context, _ db.AdminUpdateCounterParams) (db.UsageCounter, error) {
		return counterRow(3, 0, 20), nil
	}
	// The crux: the audit write fails (simulates the missing
	// audit_events.reason column).
	q.createAuditFn = func(ctx context.Context, _ db.CreateBillingAuditEventParams) (db.AuditEvent, error) {
		return db.AuditEvent{}, errors.New(`column "reason" does not exist (SQLSTATE 42703)`)
	}

	tx := &fakeTxOpener{q: q}
	s := newTestServer(q, tx)

	_, err := s.AdminChangePlan(adminCtx(), &billingv1.AdminChangePlanRequest{
		OrganizationId: uuid.New().String(),
		PlanTier:       "SOLO",
		PlanCycle:      "MONTHLY",
		Reason:         "upgrade to paid plan after trial",
	})

	if err == nil {
		t.Fatal("expected error when audit write fails, got nil (fail-loud contract broken)")
	}
	if got := status.Code(err); got != codes.Internal {
		t.Errorf("error code = %v, want Internal", got)
	}
	// The whole change must roll back — NOT commit.
	if tx.commitCalls != 0 {
		t.Errorf("commit count = %d, want 0 (tx must NOT commit when audit fails)", tx.commitCalls)
	}
	if tx.rollbackCalls != 1 {
		t.Errorf("rollback count = %d, want 1", tx.rollbackCalls)
	}
	// The plan-flip query did run (inside the tx) but is discarded by
	// the rollback — proving the operation is all-or-nothing.
	if len(q.adminChangePlanCalls) != 1 {
		t.Errorf("AdminChangeSubscriptionPlan calls = %d, want 1 (ran in-tx, then rolled back)", len(q.adminChangePlanCalls))
	}
}

// TestAdminChangePlan_HappyPathCommits is the positive control: when
// every step including the audit succeeds, the tx commits exactly once.
func TestAdminChangePlan_HappyPathCommits(t *testing.T) {
	q := &fakeQuerier{}
	q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
		return subRow(t, db.SubscriptionStatusTRIALING, 3), nil
	}
	q.adminGetPlanFn = func(ctx context.Context, _ db.AdminGetPlanByTierCycleParams) (db.SubscriptionPlan, error) {
		return db.SubscriptionPlan{ID: uuid.New(), TokensPerPeriod: 20}, nil
	}
	q.lockActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
		return counterRow(3, 0, 3), nil
	}
	q.adminUpdateCounterFn = func(ctx context.Context, _ db.AdminUpdateCounterParams) (db.UsageCounter, error) {
		return counterRow(3, 0, 20), nil
	}
	// createAuditFn unset → default success.

	tx := &fakeTxOpener{q: q}
	s := newTestServer(q, tx)

	resp, err := s.AdminChangePlan(adminCtx(), &billingv1.AdminChangePlanRequest{
		OrganizationId: uuid.New().String(),
		PlanTier:       "SOLO",
		PlanCycle:      "MONTHLY",
		Reason:         "upgrade to paid plan after trial",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if tx.commitCalls != 1 {
		t.Errorf("commit count = %d, want 1", tx.commitCalls)
	}
	if resp.TokensPerPeriod != 20 {
		t.Errorf("tokens_per_period = %d, want 20 (new plan limit)", resp.TokensPerPeriod)
	}
}
