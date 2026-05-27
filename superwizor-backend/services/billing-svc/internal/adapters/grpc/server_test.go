package grpc

import (
	"context"
	"errors"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgerrcode"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// ---------- helpers ----------

func newTestServer(q *fakeQuerier, tx *fakeTxOpener) *Server {
	if tx == nil {
		tx = &fakeTxOpener{q: q}
	}
	if tx.q == nil {
		tx.q = q
	}
	return NewServerWithDeps(q, tx, time.Hour, "test")
}

func subRow(t *testing.T, status db.SubscriptionStatus, tokensPerPeriod int32) db.GetActiveSubscriptionByOrgRow {
	t.Helper()
	return db.GetActiveSubscriptionByOrgRow{
		ID:                  uuid.New(),
		PlanID:              uuid.New(),
		OrganizationID:      uuid.New(),
		Status:              status,
		PlanTier:            db.PlanTierPRO,
		PlanTokensPerPeriod: tokensPerPeriod,
		PlanLicensesLimit:   1,
		CurrentPeriodStart:  time.Now().Add(-24 * time.Hour),
		CurrentPeriodEnd:    time.Now().Add(7 * 24 * time.Hour),
	}
}

func counterRow(used, reserved, limit int32) db.UsageCounter {
	return db.UsageCounter{
		ID:             uuid.New(),
		SubscriptionID: uuid.New(),
		PeriodStart:    time.Now().Add(-24 * time.Hour),
		PeriodEnd:      time.Now().Add(7 * 24 * time.Hour),
		TokensUsed:     used,
		TokensReserved: reserved,
		TokensLimit:    limit,
	}
}

func codeOf(err error) codes.Code {
	s, _ := status.FromError(err)
	return s.Code()
}

func uniqueViolationErr() error {
	return &pgconn.PgError{Code: pgerrcode.UniqueViolation}
}

// ---------- CheckQuota ----------

func TestCheckQuota(t *testing.T) {
	orgID := uuid.New()

	tests := []struct {
		name        string
		amount      int32
		setup       func(*fakeQuerier)
		wantAllowed bool
		wantReason  string
		wantCode    codes.Code
		wantRem     int32
	}{
		{
			name:   "happy path — quota available",
			amount: 1,
			setup: func(f *fakeQuerier) {
				sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
				f.getActiveSubFn = func(ctx context.Context, id uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
					return sub, nil
				}
				f.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
					return counterRow(5, 0, 20), nil
				}
			},
			wantAllowed: true,
			wantReason:  "OK",
			wantRem:     15,
		},
		{
			name:   "no subscription → denied",
			amount: 1,
			setup: func(f *fakeQuerier) {
				f.getActiveSubFn = func(ctx context.Context, id uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
					return db.GetActiveSubscriptionByOrgRow{}, pgx.ErrNoRows
				}
			},
			wantAllowed: false,
			wantReason:  "SUBSCRIPTION_INACTIVE",
		},
		{
			name:   "PAST_DUE blocks new reservations",
			amount: 1,
			setup: func(f *fakeQuerier) {
				sub := subRow(t, db.SubscriptionStatusPASTDUE, 20)
				f.getActiveSubFn = func(ctx context.Context, id uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
					return sub, nil
				}
			},
			wantAllowed: false,
			wantReason:  "SUBSCRIPTION_PAST_DUE",
		},
		{
			name:   "missing counter → QUOTA_COUNTER_MISSING (safety net)",
			amount: 1,
			setup: func(f *fakeQuerier) {
				sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
				f.getActiveSubFn = func(ctx context.Context, id uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
					return sub, nil
				}
				f.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
					return db.UsageCounter{}, pgx.ErrNoRows
				}
			},
			wantAllowed: false,
			wantReason:  "QUOTA_COUNTER_MISSING",
		},
		{
			name:   "quota exhausted (used + reserved == limit)",
			amount: 1,
			setup: func(f *fakeQuerier) {
				sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
				f.getActiveSubFn = func(ctx context.Context, id uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
					return sub, nil
				}
				f.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
					return counterRow(15, 5, 20), nil
				}
			},
			wantAllowed: false,
			wantReason:  "QUOTA_EXHAUSTED",
			wantRem:     0,
		},
		{
			name:   "amount default to 1 when zero",
			amount: 0,
			setup: func(f *fakeQuerier) {
				sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
				f.getActiveSubFn = func(ctx context.Context, id uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
					return sub, nil
				}
				f.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
					return counterRow(0, 0, 20), nil
				}
			},
			wantAllowed: true,
			wantReason:  "OK",
			wantRem:     20,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			q := &fakeQuerier{}
			tt.setup(q)
			s := newTestServer(q, nil)

			resp, err := s.CheckQuota(context.Background(), &billingv1.CheckQuotaRequest{
				OrganizationId: orgID.String(),
				Amount:         tt.amount,
				UsageType:      "session_analysis",
			})

			if tt.wantCode != codes.OK {
				if codeOf(err) != tt.wantCode {
					t.Fatalf("want code %v, got %v (%v)", tt.wantCode, codeOf(err), err)
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if resp.Allowed != tt.wantAllowed {
				t.Errorf("allowed = %v, want %v", resp.Allowed, tt.wantAllowed)
			}
			if resp.Reason != tt.wantReason {
				t.Errorf("reason = %q, want %q", resp.Reason, tt.wantReason)
			}
			if tt.wantAllowed || tt.wantReason == "QUOTA_EXHAUSTED" {
				if resp.Remaining != tt.wantRem {
					t.Errorf("remaining = %d, want %d", resp.Remaining, tt.wantRem)
				}
				if resp.RemainingTokens != tt.wantRem {
					t.Errorf("remaining_tokens alias = %d, want %d", resp.RemainingTokens, tt.wantRem)
				}
			}
		})
	}
}

func TestCheckQuota_InvalidOrgID(t *testing.T) {
	s := newTestServer(&fakeQuerier{}, nil)
	_, err := s.CheckQuota(context.Background(), &billingv1.CheckQuotaRequest{OrganizationId: "not-uuid"})
	if codeOf(err) != codes.InvalidArgument {
		t.Fatalf("want InvalidArgument, got %v", err)
	}
}

// ---------- ReserveCredit ----------

func TestReserveCredit(t *testing.T) {
	orgID := uuid.New()
	sessionID := uuid.New()

	t.Run("happy path", func(t *testing.T) {
		q := &fakeQuerier{}
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		// pre-check finds no reservation
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{}, pgx.ErrNoRows
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(5, 0, 20), nil
		}
		expiresAt := time.Now().Add(4 * time.Hour)
		q.createReservationFn = func(ctx context.Context, arg db.CreateReservationParams) (db.PendingReservation, error) {
			return db.PendingReservation{
				ID:             uuid.New(),
				SessionID:      arg.SessionID,
				TokensReserved: arg.TokensReserved,
				ExpiresAt:      expiresAt,
				Status:         db.ReservationStatusACTIVE,
			}, nil
		}
		tx := &fakeTxOpener{q: q}
		s := newTestServer(q, tx)

		resp, err := s.ReserveCredit(context.Background(), &billingv1.ReserveCreditRequest{
			SessionId:       sessionID.String(),
			OrganizationId:  orgID.String(),
			EstimatedTokens: 1,
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.TokensReserved != 1 {
			t.Errorf("tokens_reserved = %d, want 1", resp.TokensReserved)
		}
		if tx.commitCalls != 1 {
			t.Errorf("commit count = %d, want 1", tx.commitCalls)
		}
		if len(q.advisoryLockCalls) != 1 {
			t.Errorf("advisory lock called %d times, want 1", len(q.advisoryLockCalls))
		}
		if len(q.addReservedCalls) != 1 || q.addReservedCalls[0].TokensReserved != 1 {
			t.Errorf("AddReservedTokens not called correctly: %+v", q.addReservedCalls)
		}
	})

	t.Run("idempotent: existing reservation returned without DB write", func(t *testing.T) {
		q := &fakeQuerier{}
		existing := db.PendingReservation{
			ID:             uuid.New(),
			SessionID:      sessionID,
			TokensReserved: 1,
			Status:         db.ReservationStatusACTIVE,
			ExpiresAt:      time.Now().Add(time.Hour),
		}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return existing, nil
		}
		// Idempotent path now fetches sub + counter to populate
		// state_after on the response (refactor phase A). Stub both.
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(2, 1, 20), nil
		}
		tx := &fakeTxOpener{q: q}
		s := newTestServer(q, tx)

		resp, err := s.ReserveCredit(context.Background(), &billingv1.ReserveCreditRequest{
			SessionId:      sessionID.String(),
			OrganizationId: orgID.String(),
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.ReservationId != existing.ID.String() {
			t.Errorf("returned different reservation_id")
		}
		if tx.beginCalls != 0 {
			t.Errorf("tx.Begin called %d times, want 0 (pre-check should short-circuit)", tx.beginCalls)
		}
		// state_after populated from current counter (used=2, reserved=1, limit=20).
		if resp.StateAfter == nil {
			t.Fatalf("expected state_after on idempotent return, got nil")
		}
		if got := resp.StateAfter.TokensRemaining; got != 17 {
			t.Errorf("state_after.tokens_remaining = %d, want 17 (= 20 - 2 - 1)", got)
		}
	})

	t.Run("quota exhausted → ResourceExhausted", func(t *testing.T) {
		q := &fakeQuerier{}
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{}, pgx.ErrNoRows
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(20, 0, 20), nil // pełna pula
		}
		s := newTestServer(q, nil)

		_, err := s.ReserveCredit(context.Background(), &billingv1.ReserveCreditRequest{
			SessionId:       sessionID.String(),
			OrganizationId:  orgID.String(),
			EstimatedTokens: 1,
		})
		if codeOf(err) != codes.ResourceExhausted {
			t.Fatalf("want ResourceExhausted, got %v", err)
		}
		if !errors.Is(err, err) || status.Convert(err).Message() != "QUOTA_EXHAUSTED" {
			t.Errorf("want reason QUOTA_EXHAUSTED in message, got %v", err)
		}
	})

	t.Run("past_due blocks new reservation", func(t *testing.T) {
		q := &fakeQuerier{}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{}, pgx.ErrNoRows
		}
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return subRow(t, db.SubscriptionStatusPASTDUE, 20), nil
		}
		s := newTestServer(q, nil)

		_, err := s.ReserveCredit(context.Background(), &billingv1.ReserveCreditRequest{
			SessionId:      sessionID.String(),
			OrganizationId: orgID.String(),
		})
		if codeOf(err) != codes.FailedPrecondition {
			t.Fatalf("want FailedPrecondition, got %v", err)
		}
	})

	t.Run("race: unique violation → refetch and return existing", func(t *testing.T) {
		q := &fakeQuerier{}
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		callCount := 0
		existing := db.PendingReservation{
			ID:             uuid.New(),
			SessionID:      sessionID,
			TokensReserved: 1,
			Status:         db.ReservationStatusACTIVE,
			ExpiresAt:      time.Now().Add(time.Hour),
		}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			callCount++
			if callCount == 1 {
				// pre-check: no reservation
				return db.PendingReservation{}, pgx.ErrNoRows
			}
			// post-race refetch: returns the row inserted by the racing peer
			return existing, nil
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(0, 0, 20), nil
		}
		q.createReservationFn = func(ctx context.Context, _ db.CreateReservationParams) (db.PendingReservation, error) {
			return db.PendingReservation{}, uniqueViolationErr()
		}
		s := newTestServer(q, nil)

		resp, err := s.ReserveCredit(context.Background(), &billingv1.ReserveCreditRequest{
			SessionId:      sessionID.String(),
			OrganizationId: orgID.String(),
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.ReservationId != existing.ID.String() {
			t.Errorf("expected refetched reservation_id %s, got %s", existing.ID, resp.ReservationId)
		}
	})
}

// ---------- CommitUsage ----------

func TestCommitUsage(t *testing.T) {
	orgID := uuid.New()
	sessionID := uuid.New()

	t.Run("happy path: 45min session → 1 token", func(t *testing.T) {
		q := &fakeQuerier{}
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		q.getUsageEventFn = func(ctx context.Context, _ uuid.UUID) (db.UsageEvent, error) {
			return db.UsageEvent{}, pgx.ErrNoRows
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(5, 1, 20), nil
		}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{
				ID:             uuid.New(),
				SessionID:      sessionID,
				SubscriptionID: sub.ID,
				TokensReserved: 1,
				Status:         db.ReservationStatusACTIVE,
				ExpiresAt:      time.Now().Add(time.Hour),
			}, nil
		}
		q.createUsageEventFn = func(ctx context.Context, arg db.CreateUsageEventParams) (db.UsageEvent, error) {
			return db.UsageEvent{
				ID:              uuid.New(),
				SessionID:       arg.SessionID,
				TokensConsumed:  arg.TokensConsumed,
				DurationSeconds: arg.DurationSeconds,
				UsageType:       arg.UsageType,
			}, nil
		}
		tx := &fakeTxOpener{q: q}
		s := newTestServer(q, tx)

		resp, err := s.CommitUsage(context.Background(), &billingv1.CommitUsageRequest{
			SessionId:       sessionID.String(),
			OrganizationId:  orgID.String(),
			DurationSeconds: 2700, // 45min
		})
		if err != nil {
			t.Fatalf("unexpected error: %v", err)
		}
		if resp.TokensConsumed != 1 {
			t.Errorf("tokens_consumed = %d, want 1 (45min should be 1 token)", resp.TokensConsumed)
		}
		if tx.commitCalls != 1 {
			t.Errorf("expected 1 commit, got %d", tx.commitCalls)
		}
		// Counter UPDATE: tokens_used += 1, tokens_reserved -= 1 (had reservation)
		if len(q.commitTokensCalls) != 1 {
			t.Fatalf("expected 1 CommitTokens call, got %d", len(q.commitTokensCalls))
		}
		if q.commitTokensCalls[0].TokensUsed != 1 || q.commitTokensCalls[0].TokensReserved != 1 {
			t.Errorf("CommitTokens args wrong: %+v", q.commitTokensCalls[0])
		}
	})

	t.Run("idempotent: existing usage_event → no-op snapshot", func(t *testing.T) {
		q := &fakeQuerier{}
		existing := db.UsageEvent{
			ID:             uuid.New(),
			SessionID:      sessionID,
			TokensConsumed: 1,
		}
		q.getUsageEventFn = func(ctx context.Context, _ uuid.UUID) (db.UsageEvent, error) {
			return existing, nil
		}
		// snapshotAfterCommit looks up sub + counter
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return subRow(t, db.SubscriptionStatusACTIVE, 20), nil
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(6, 0, 20), nil
		}
		tx := &fakeTxOpener{q: q}
		s := newTestServer(q, tx)

		resp, err := s.CommitUsage(context.Background(), &billingv1.CommitUsageRequest{
			SessionId:       sessionID.String(),
			OrganizationId:  orgID.String(),
			DurationSeconds: 2700,
		})
		if err != nil {
			t.Fatalf("unexpected: %v", err)
		}
		if resp.TokensConsumed != 1 {
			t.Errorf("tokens_consumed = %d, want 1 (idempotent return of existing)", resp.TokensConsumed)
		}
		if tx.beginCalls != 0 {
			t.Errorf("idempotent path should not open tx, got %d begin calls", tx.beginCalls)
		}
	})

	t.Run("63min boundary still 1 token (grace period)", func(t *testing.T) {
		q := &fakeQuerier{}
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		q.getUsageEventFn = func(ctx context.Context, _ uuid.UUID) (db.UsageEvent, error) {
			return db.UsageEvent{}, pgx.ErrNoRows
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(0, 0, 20), nil
		}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{}, pgx.ErrNoRows
		}
		q.createUsageEventFn = func(ctx context.Context, arg db.CreateUsageEventParams) (db.UsageEvent, error) {
			return db.UsageEvent{TokensConsumed: arg.TokensConsumed}, nil
		}
		s := newTestServer(q, nil)

		resp, err := s.CommitUsage(context.Background(), &billingv1.CommitUsageRequest{
			SessionId:       sessionID.String(),
			OrganizationId:  orgID.String(),
			DurationSeconds: 3780, // 63min — boundary
		})
		if err != nil {
			t.Fatalf("unexpected: %v", err)
		}
		if resp.TokensConsumed != 1 {
			t.Errorf("63min boundary should still be 1 token, got %d", resp.TokensConsumed)
		}
	})

	t.Run("64min → 2 tokens", func(t *testing.T) {
		q := &fakeQuerier{}
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		q.getUsageEventFn = func(ctx context.Context, _ uuid.UUID) (db.UsageEvent, error) {
			return db.UsageEvent{}, pgx.ErrNoRows
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(0, 0, 20), nil
		}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{}, pgx.ErrNoRows
		}
		q.createUsageEventFn = func(ctx context.Context, arg db.CreateUsageEventParams) (db.UsageEvent, error) {
			return db.UsageEvent{TokensConsumed: arg.TokensConsumed}, nil
		}
		s := newTestServer(q, nil)

		resp, err := s.CommitUsage(context.Background(), &billingv1.CommitUsageRequest{
			SessionId:       sessionID.String(),
			OrganizationId:  orgID.String(),
			DurationSeconds: 3840, // 64min
		})
		if err != nil {
			t.Fatalf("unexpected: %v", err)
		}
		if resp.TokensConsumed != 2 {
			t.Errorf("64min should consume 2 tokens, got %d", resp.TokensConsumed)
		}
	})

	// Phase C of the client-cache refactor removed outbox emission
	// entirely. The previous "emits quota.warning/critical/exhausted/updated"
	// subtests are gone with it; the client now reads counter state
	// directly via clinical-svc.GetMyBillingState + state_after on
	// Reservation/UsageCommit.

	t.Run("legacy IncrementUsage maps amount → tokens", func(t *testing.T) {
		q := &fakeQuerier{}
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		q.getUsageEventFn = func(ctx context.Context, _ uuid.UUID) (db.UsageEvent, error) {
			return db.UsageEvent{}, pgx.ErrNoRows
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(0, 0, 20), nil
		}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{}, pgx.ErrNoRows
		}
		q.createUsageEventFn = func(ctx context.Context, arg db.CreateUsageEventParams) (db.UsageEvent, error) {
			return db.UsageEvent{TokensConsumed: arg.TokensConsumed}, nil
		}
		s := newTestServer(q, nil)

		//nolint:staticcheck // celowo testujemy deprecated alias path
		_, err := s.IncrementUsage(context.Background(), &billingv1.IncrementUsageRequest{
			SessionId:      sessionID.String(),
			OrganizationId: orgID.String(),
			Amount:         3,
		})
		if err != nil {
			t.Fatalf("unexpected: %v", err)
		}
		if len(q.createUsageEventCalls) != 1 || q.createUsageEventCalls[0].TokensConsumed != 3 {
			t.Errorf("legacy amount should map to tokens 1:1, got %+v", q.createUsageEventCalls)
		}
	})
}

// ---------- ReleaseCredit ----------

func TestReleaseCredit(t *testing.T) {
	sessionID := uuid.New()
	orgID := uuid.New()

	t.Run("happy path: active reservation released", func(t *testing.T) {
		q := &fakeQuerier{}
		subID := uuid.New()
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{
				ID:             uuid.New(),
				SessionID:      sessionID,
				SubscriptionID: subID,
				OrganizationID: orgID,
				TokensReserved: 1,
				Status:         db.ReservationStatusACTIVE,
				ExpiresAt:      time.Now().Add(time.Hour),
			}, nil
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(0, 1, 20), nil
		}
		tx := &fakeTxOpener{q: q}
		s := newTestServer(q, tx)

		_, err := s.ReleaseCredit(context.Background(), &billingv1.ReleaseCreditRequest{
			SessionId:      sessionID.String(),
			OrganizationId: orgID.String(),
			Reason:         "UPLOAD_FAILED",
		})
		if err != nil {
			t.Fatalf("unexpected: %v", err)
		}
		if len(q.releaseReservedCalls) != 1 || q.releaseReservedCalls[0].TokensReserved != 1 {
			t.Errorf("ReleaseReservedTokens not called correctly: %+v", q.releaseReservedCalls)
		}
		if tx.commitCalls != 1 {
			t.Errorf("expected commit")
		}
	})

	t.Run("idempotent: already released → no-op", func(t *testing.T) {
		q := &fakeQuerier{}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{
				Status: db.ReservationStatusRELEASED,
			}, nil
		}
		tx := &fakeTxOpener{q: q}
		s := newTestServer(q, tx)

		_, err := s.ReleaseCredit(context.Background(), &billingv1.ReleaseCreditRequest{
			SessionId:      sessionID.String(),
			OrganizationId: orgID.String(),
		})
		if err != nil {
			t.Fatalf("unexpected: %v", err)
		}
		if tx.beginCalls != 0 {
			t.Errorf("non-ACTIVE reservation should short-circuit, got %d begin calls", tx.beginCalls)
		}
	})

	t.Run("no reservation found → no-op success", func(t *testing.T) {
		q := &fakeQuerier{}
		q.getReservationFn = func(ctx context.Context, _ uuid.UUID) (db.PendingReservation, error) {
			return db.PendingReservation{}, pgx.ErrNoRows
		}
		tx := &fakeTxOpener{q: q}
		s := newTestServer(q, tx)

		_, err := s.ReleaseCredit(context.Background(), &billingv1.ReleaseCreditRequest{
			SessionId:      sessionID.String(),
			OrganizationId: orgID.String(),
		})
		if err != nil {
			t.Fatalf("unexpected: %v", err)
		}
		if tx.beginCalls != 0 {
			t.Errorf("missing reservation should not open tx")
		}
	})
}

// ---------- GetSubscription ----------

func TestGetSubscription(t *testing.T) {
	orgID := uuid.New()

	t.Run("returns both legacy and new fields populated identically", func(t *testing.T) {
		q := &fakeQuerier{}
		sub := subRow(t, db.SubscriptionStatusACTIVE, 20)
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return sub, nil
		}
		q.getActiveCounterFn = func(ctx context.Context, _ uuid.UUID) (db.UsageCounter, error) {
			return counterRow(7, 2, 20), nil
		}
		s := newTestServer(q, nil)

		resp, err := s.GetSubscription(context.Background(), &billingv1.GetSubscriptionRequest{
			OrganizationId: orgID.String(),
		})
		if err != nil {
			t.Fatalf("unexpected: %v", err)
		}
		if resp.SessionsPerMonthLimit != 20 || resp.TokensPerPeriod != 20 {
			t.Errorf("legacy/new limit fields mismatch: legacy=%d new=%d", resp.SessionsPerMonthLimit, resp.TokensPerPeriod)
		}
		if resp.SessionsUsedThisPeriod != 7 || resp.TokensUsedThisPeriod != 7 {
			t.Errorf("legacy/new used fields mismatch: legacy=%d new=%d", resp.SessionsUsedThisPeriod, resp.TokensUsedThisPeriod)
		}
		if resp.TokensReservedThisPeriod != 2 {
			t.Errorf("tokens_reserved_this_period = %d, want 2", resp.TokensReservedThisPeriod)
		}
	})

	t.Run("no subscription → NotFound", func(t *testing.T) {
		q := &fakeQuerier{}
		q.getActiveSubFn = func(ctx context.Context, _ uuid.UUID) (db.GetActiveSubscriptionByOrgRow, error) {
			return db.GetActiveSubscriptionByOrgRow{}, pgx.ErrNoRows
		}
		s := newTestServer(q, nil)

		_, err := s.GetSubscription(context.Background(), &billingv1.GetSubscriptionRequest{
			OrganizationId: orgID.String(),
		})
		if codeOf(err) != codes.NotFound {
			t.Fatalf("want NotFound, got %v", err)
		}
	})
}
