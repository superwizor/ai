package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Reported 2026-08-01: the phone showed a different session budget than
// the organization panel for the same therapist in the same period.
//
// Root cause: the WRITE path (lockDebitCounter, counter_scope_test.go)
// has debited the per-therapist counter since docs/38, but the READ path
// (GetSubscription) always answered with the org-level row. Both rows
// exist simultaneously — they are two different budgets, not two views
// of one — so the app reported the org's 40/0 while the therapist's own
// seat stood at 30/1.
//
// The setup below is deliberately the awkward one: BOTH counters
// present. A fixture with only a therapist counter would pass against
// the buggy code too, because the org lookup would simply miss.

func bothCountersQuerier(t *testing.T, sub db.GetActiveSubscriptionByOrgRow, therapist uuid.UUID) *fakeQuerier {
	t.Helper()
	return &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		// org-level budget — what the buggy build returned
		getActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return db.UsageCounter{
				ID: uuid.New(), SubscriptionID: sub.ID,
				TokensLimit: 40, TokensUsed: 0, TokensReserved: 0,
			}, nil
		},
		// the therapist's actual seat — what the org panel shows
		getCounterForTherapistFn: func(_ context.Context, arg db.GetActiveCounterForTherapistParams) (db.UsageCounter, error) {
			if uuid.UUID(arg.TherapistID.Bytes) != therapist {
				t.Fatalf("counter looked up for the wrong therapist: %v", arg.TherapistID)
			}
			return db.UsageCounter{
				ID: uuid.New(), SubscriptionID: sub.ID,
				TokensLimit: 30, TokensUsed: 1, TokensReserved: 0,
			}, nil
		},
	}
}

func TestGetSubscription_TherapistCounterWins_WhenBothCountersExist(t *testing.T) {
	org, therapist := uuid.New(), uuid.New()
	sub := scopeSub(org)
	sub.PlanTokensPerPeriod = 90

	q := bothCountersQuerier(t, sub, therapist)
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	got, err := s.GetSubscription(context.Background(), &billingv1.GetSubscriptionRequest{
		OrganizationId: org.String(),
		TherapistId:    therapist.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.TokensPerPeriod != 30 {
		t.Errorf("limit = %d, want 30 (own seat); 40 means the org-level counter leaked back in",
			got.TokensPerPeriod)
	}
	if got.TokensUsedThisPeriod != 1 {
		t.Errorf("used = %d, want 1 — the app must agree with the org panel",
			got.TokensUsedThisPeriod)
	}
}

// The field is additive: every existing server-to-server caller omits it
// and must keep seeing the organization-wide numbers.
func TestGetSubscription_WithoutTherapistID_StaysOrgLevel(t *testing.T) {
	org := uuid.New()
	sub := scopeSub(org)

	q := bothCountersQuerier(t, sub, uuid.New())
	q.getCounterForTherapistFn = func(_ context.Context, _ db.GetActiveCounterForTherapistParams) (db.UsageCounter, error) {
		t.Fatal("per-therapist counter must not be consulted without therapist_id")
		return db.UsageCounter{}, nil
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	got, err := s.GetSubscription(context.Background(), &billingv1.GetSubscriptionRequest{
		OrganizationId: org.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.TokensPerPeriod != 40 {
		t.Errorf("limit = %d, want 40 (org-level, unchanged behaviour)", got.TokensPerPeriod)
	}
}

// A solo therapist, or one whose counter hasn't been minted yet, has no
// per-therapist row. That must degrade to the previous behaviour rather
// than report a zero budget.
func TestGetSubscription_TherapistWithoutCounter_FallsBackToOrg(t *testing.T) {
	org, therapist := uuid.New(), uuid.New()
	sub := scopeSub(org)

	q := bothCountersQuerier(t, sub, therapist)
	q.getCounterForTherapistFn = func(_ context.Context, _ db.GetActiveCounterForTherapistParams) (db.UsageCounter, error) {
		return db.UsageCounter{}, pgx.ErrNoRows
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	got, err := s.GetSubscription(context.Background(), &billingv1.GetSubscriptionRequest{
		OrganizationId: org.String(),
		TherapistId:    therapist.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.TokensPerPeriod != 40 {
		t.Errorf("limit = %d, want 40 (org fallback)", got.TokensPerPeriod)
	}
}

// therapist_id turns this into a per-person usage read, so it needs its
// own scope check — otherwise a therapist could pass a colleague's id
// and read their consumption.
func TestGetSubscription_TherapistCannotReadColleague(t *testing.T) {
	org, caller, colleague := uuid.New(), uuid.New(), uuid.New()
	sub := scopeSub(org)

	q := bothCountersQuerier(t, sub, colleague)
	q.getCounterForTherapistFn = func(_ context.Context, _ db.GetActiveCounterForTherapistParams) (db.UsageCounter, error) {
		t.Fatal("must be rejected before any counter lookup")
		return db.UsageCounter{}, nil
	}
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs(
		"x-superwizor-role", "THERAPIST",
		"x-superwizor-organization-id", org.String(),
		"x-superwizor-user-id", caller.String(),
	))
	_, err := s.GetSubscription(ctx, &billingv1.GetSubscriptionRequest{
		OrganizationId: org.String(),
		TherapistId:    colleague.String(),
	})
	if status.Code(err) != codes.PermissionDenied {
		t.Fatalf("code = %v, want PermissionDenied", status.Code(err))
	}
}

// The org panel is built on exactly this call, so an admin must keep the
// wider view.
func TestGetSubscription_OrgAdminMayReadTherapist(t *testing.T) {
	org, admin, therapist := uuid.New(), uuid.New(), uuid.New()
	sub := scopeSub(org)

	q := bothCountersQuerier(t, sub, therapist)
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs(
		"x-superwizor-role", "ORG_ADMIN",
		"x-superwizor-organization-id", org.String(),
		"x-superwizor-user-id", admin.String(),
	))
	got, err := s.GetSubscription(ctx, &billingv1.GetSubscriptionRequest{
		OrganizationId: org.String(),
		TherapistId:    therapist.String(),
	})
	if err != nil {
		t.Fatalf("org admin must be allowed: %v", err)
	}
	if got.TokensPerPeriod != 30 {
		t.Errorf("limit = %d, want 30", got.TokensPerPeriod)
	}
}

// A therapist reading their OWN usage is the whole point of the field.
func TestGetSubscription_TherapistMayReadSelf(t *testing.T) {
	org, therapist := uuid.New(), uuid.New()
	sub := scopeSub(org)

	q := bothCountersQuerier(t, sub, therapist)
	s := NewServerWithDeps(q, &fakeTxOpener{q: q}, time.Hour, "test", nil)

	ctx := metadata.NewIncomingContext(context.Background(), metadata.Pairs(
		"x-superwizor-role", "THERAPIST",
		"x-superwizor-organization-id", org.String(),
		"x-superwizor-user-id", therapist.String(),
	))
	got, err := s.GetSubscription(ctx, &billingv1.GetSubscriptionRequest{
		OrganizationId: org.String(),
		TherapistId:    therapist.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if got.TokensUsedThisPeriod != 1 {
		t.Errorf("used = %d, want 1", got.TokensUsedThisPeriod)
	}
}
