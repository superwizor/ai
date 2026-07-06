package grpc

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Regression tests for the per-therapist counter model (docs/38,
// decision 2026-07-03): scope resolution, lazy minting, and the
// debit/credit-same-counter invariant.

func scopeSub(orgID uuid.UUID) db.GetActiveSubscriptionByOrgRow {
	return db.GetActiveSubscriptionByOrgRow{
		ID:                 uuid.New(),
		OrganizationID:     orgID,
		Status:             db.SubscriptionStatusACTIVE,
		CurrentPeriodStart: time.Now().Add(-time.Hour),
		CurrentPeriodEnd:   time.Now().Add(29 * 24 * time.Hour),
		PlanTier:           "CLINIC",
		PlanCycle:          "MONTHLY",
	}
}

func pgUUIDOf(id uuid.UUID) pgtype.UUID { return pgtype.UUID{Bytes: id, Valid: true} }

func TestLockDebitCounter_TherapistCounterWins(t *testing.T) {
	org := uuid.New()
	therapist := uuid.New()
	sub := scopeSub(org)
	tCounter := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 100}

	q := &fakeQuerier{
		lockCounterForTherapistFn: func(_ context.Context, arg db.LockActiveCounterForTherapistParams) (db.UsageCounter, error) {
			if arg.SubscriptionID != sub.ID || uuid.UUID(arg.TherapistID.Bytes) != therapist {
				t.Fatalf("wrong lock args: %+v", arg)
			}
			return tCounter, nil
		},
		// LockActiveCounter (org-level) must NOT be reached — nil fn would
		// fall back to getActiveCounterFn which is also nil → panic.
	}

	c, scope, err := lockDebitCounter(context.Background(), q, sub, pgUUIDOf(therapist))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.ID != tCounter.ID {
		t.Errorf("wrong counter locked")
	}
	if !scope.Valid || uuid.UUID(scope.Bytes) != therapist {
		t.Errorf("scope must be the therapist, got %v", scope)
	}
}

func TestLockDebitCounter_SeatedTherapist_LazyMint(t *testing.T) {
	org := uuid.New()
	therapist := uuid.New()
	sub := scopeSub(org)
	minted := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 120}

	q := &fakeQuerier{
		lockCounterForTherapistFn: func(_ context.Context, _ db.LockActiveCounterForTherapistParams) (db.UsageCounter, error) {
			return db.UsageCounter{}, pgx.ErrNoRows
		},
		getSeatPlanFn: func(_ context.Context, uid uuid.UUID) (db.GetSeatPlanForTherapistRow, error) {
			if uid != therapist {
				t.Fatalf("seat lookup for wrong user %s", uid)
			}
			return db.GetSeatPlanForTherapistRow{
				OrganizationID:  org, // seated in THIS org
				PlanID:          uuid.New(),
				TokensPerPeriod: 120,
			}, nil
		},
		createTherapistCounterFn: func(_ context.Context, arg db.CreateTherapistUsageCounterParams) (db.UsageCounter, error) {
			if arg.TokensLimit != 120 {
				t.Errorf("minted counter limit = %d, want 120 (seat plan)", arg.TokensLimit)
			}
			if !arg.PeriodStart.Equal(sub.CurrentPeriodStart) || !arg.PeriodEnd.Equal(sub.CurrentPeriodEnd) {
				t.Errorf("minted counter must span the subscription period")
			}
			return minted, nil
		},
	}

	c, scope, err := lockDebitCounter(context.Background(), q, sub, pgUUIDOf(therapist))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.ID != minted.ID {
		t.Errorf("must use the freshly minted counter")
	}
	if !scope.Valid {
		t.Errorf("scope must be per-therapist after lazy mint")
	}
	if len(q.createTherapistCounterCalls) != 1 {
		t.Errorf("expected exactly 1 mint, got %d", len(q.createTherapistCounterCalls))
	}
}

func TestLockDebitCounter_MintRace_RelocksWinner(t *testing.T) {
	org := uuid.New()
	therapist := uuid.New()
	sub := scopeSub(org)
	winner := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 120}

	locks := 0
	q := &fakeQuerier{
		lockCounterForTherapistFn: func(_ context.Context, _ db.LockActiveCounterForTherapistParams) (db.UsageCounter, error) {
			locks++
			if locks == 1 {
				return db.UsageCounter{}, pgx.ErrNoRows // first look: nothing
			}
			return winner, nil // after the race: winner's row
		},
		getSeatPlanFn: func(_ context.Context, _ uuid.UUID) (db.GetSeatPlanForTherapistRow, error) {
			return db.GetSeatPlanForTherapistRow{OrganizationID: org, TokensPerPeriod: 120}, nil
		},
		createTherapistCounterFn: func(_ context.Context, _ db.CreateTherapistUsageCounterParams) (db.UsageCounter, error) {
			// ON CONFLICT DO NOTHING: a concurrent mint that already
			// inserted the row makes our insert a no-op → no row →
			// pgx.ErrNoRows (previously this surfaced as a raw 23505).
			return db.UsageCounter{}, pgx.ErrNoRows
		},
	}

	c, scope, err := lockDebitCounter(context.Background(), q, sub, pgUUIDOf(therapist))
	if err != nil {
		t.Fatalf("race must resolve to the winner's counter: %v", err)
	}
	if c.ID != winner.ID || !scope.Valid {
		t.Errorf("must lock the winner's counter with therapist scope")
	}
}

func TestLockDebitCounter_SeatlessTherapist_OrgFallback(t *testing.T) {
	org := uuid.New()
	sub := scopeSub(org)
	orgCounter := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 50}

	q := &fakeQuerier{
		lockCounterForTherapistFn: func(_ context.Context, _ db.LockActiveCounterForTherapistParams) (db.UsageCounter, error) {
			return db.UsageCounter{}, pgx.ErrNoRows
		},
		getSeatPlanFn: func(_ context.Context, _ uuid.UUID) (db.GetSeatPlanForTherapistRow, error) {
			return db.GetSeatPlanForTherapistRow{}, pgx.ErrNoRows // no seat
		},
		lockActiveCounterFn: func(_ context.Context, subID uuid.UUID) (db.UsageCounter, error) {
			return orgCounter, nil
		},
	}

	c, scope, err := lockDebitCounter(context.Background(), q, sub, pgUUIDOf(uuid.New()))
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if c.ID != orgCounter.ID {
		t.Errorf("seatless therapist must debit the org-level counter")
	}
	if scope.Valid {
		t.Errorf("scope must be org-level (invalid UUID) for seatless callers")
	}
}

func TestLockDebitCounter_NoTherapist_OrgLevel(t *testing.T) {
	org := uuid.New()
	sub := scopeSub(org)
	orgCounter := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 50}

	q := &fakeQuerier{
		lockActiveCounterFn: func(_ context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return orgCounter, nil
		},
	}

	c, scope, err := lockDebitCounter(context.Background(), q, sub, pgtype.UUID{})
	if err != nil || c.ID != orgCounter.ID || scope.Valid {
		t.Fatalf("legacy path must stay org-level: c=%v scope=%v err=%v", c.ID, scope, err)
	}
}

// ReserveCredit must record the debited scope on the reservation so
// release/commit/expiry credit the same counter.
func TestReserveCredit_RecordsTherapistScopeOnReservation(t *testing.T) {
	org := uuid.New()
	therapist := uuid.New()
	sessionID := uuid.New()
	sub := scopeSub(org)
	tCounter := db.UsageCounter{ID: uuid.New(), SubscriptionID: sub.ID, TokensLimit: 100}

	q := &fakeQuerier{
		getActiveSubFn: func(_ context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		},
		getReservationFn: func(_ context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{}, pgx.ErrNoRows
		},
		lockCounterForTherapistFn: func(_ context.Context, _ db.LockActiveCounterForTherapistParams) (db.UsageCounter, error) {
			return tCounter, nil
		},
		createReservationFn: func(_ context.Context, arg db.CreateReservationParams) (db.PendingReservation, error) {
			return db.PendingReservation{
				ID: uuid.New(), SessionID: arg.SessionID, SubscriptionID: arg.SubscriptionID,
				TherapistID: arg.TherapistID, TokensReserved: arg.TokensReserved,
				ExpiresAt: arg.ExpiresAt,
			}, nil
		},
	}
	opener := &fakeTxOpener{q: q}
	s := NewServerWithDeps(q, opener, time.Hour, "test", nil)

	_, err := s.ReserveCredit(context.Background(), &billingv1.ReserveCreditRequest{
		SessionId:      sessionID.String(),
		OrganizationId: org.String(),
		TherapistId:    therapist.String(),
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(q.createReservationCalls) != 1 {
		t.Fatalf("expected 1 reservation, got %d", len(q.createReservationCalls))
	}
	got := q.createReservationCalls[0].TherapistID
	if !got.Valid || uuid.UUID(got.Bytes) != therapist {
		t.Errorf("reservation must record therapist scope, got %v", got)
	}
	if len(q.addReservedCalls) != 1 || q.addReservedCalls[0].ID != tCounter.ID {
		t.Errorf("tokens must be reserved on the therapist's counter")
	}
}

// ReleaseCredit must credit back the counter recorded on the reservation.
func TestReleaseCredit_CreditsTherapistScopedCounter(t *testing.T) {
	therapist := uuid.New()
	sessionID := uuid.New()
	subID := uuid.New()
	tCounter := db.UsageCounter{ID: uuid.New(), SubscriptionID: subID, TokensLimit: 100, TokensReserved: 1}

	q := &fakeQuerier{
		getReservationFn: func(_ context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{
				ID: uuid.New(), SessionID: sessionID, SubscriptionID: subID,
				TherapistID: pgUUIDOf(therapist), TokensReserved: 1,
				Status: db.ReservationStatusACTIVE,
			}, nil
		},
		lockCounterForTherapistFn: func(_ context.Context, arg db.LockActiveCounterForTherapistParams) (db.UsageCounter, error) {
			if uuid.UUID(arg.TherapistID.Bytes) != therapist {
				t.Fatalf("must lock the reservation's therapist counter")
			}
			return tCounter, nil
		},
		// org-level LockActiveCounter must not be touched (nil fn+nil
		// getActiveCounterFn ⇒ panic if reached).
	}
	opener := &fakeTxOpener{q: q}
	s := NewServerWithDeps(q, opener, time.Hour, "test", nil)

	_, err := s.ReleaseCredit(context.Background(), &billingv1.ReleaseCreditRequest{
		SessionId: sessionID.String(),
		Reason:    "UPLOAD_FAILED",
	})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(q.releaseReservedCalls) != 1 || q.releaseReservedCalls[0].ID != tCounter.ID {
		t.Errorf("release must credit the therapist-scoped counter, calls=%+v", q.releaseReservedCalls)
	}
}
