package grpc

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"

	"github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/postgres/db"
)

// Counter scope resolution (docs/38 billing model, decision 2026-07-03).
//
// Enforcement is per seat: a therapist with an open seat assignment
// debits THEIR OWN usage_counter (tokens_limit = their seat's plan);
// everyone else — solo therapists, orgs without allocations, seatless
// edge cases — debits the org-level counter (therapist_id IS NULL),
// exactly as before the change. Release/commit/expiry credit the SAME
// scope that was debited, recorded on pending_reservations.therapist_id.
//
// Per-therapist counters are minted LAZILY on first debit in a period
// (and eagerly for already-seated therapists by AdminSetSeatAllocations).
// Lazy minting keeps the renewal cron simple: it only rolls the
// subscription period; new-period counters appear on first use.

// counterScopeQuerier is the query subset the resolution helpers need —
// satisfied by both *db.Queries and the test fakes.
type counterScopeQuerier interface {
	LockActiveCounter(ctx context.Context, subscriptionID uuid.UUID) (db.UsageCounter, error)
	LockActiveCounterForTherapist(ctx context.Context, arg db.LockActiveCounterForTherapistParams) (db.UsageCounter, error)
	GetActiveCounter(ctx context.Context, subscriptionID uuid.UUID) (db.UsageCounter, error)
	GetActiveCounterForTherapist(ctx context.Context, arg db.GetActiveCounterForTherapistParams) (db.UsageCounter, error)
	GetSeatPlanForTherapist(ctx context.Context, userID uuid.UUID) (db.GetSeatPlanForTherapistRow, error)
	CreateTherapistUsageCounter(ctx context.Context, arg db.CreateTherapistUsageCounterParams) (db.UsageCounter, error)
}

// lockDebitCounter resolves + row-locks the counter a debit should hit.
// MUST run inside a tx that already holds AcquireSubscriptionLock.
//
// Returns the locked counter and the scope it belongs to: a Valid UUID
// = that therapist's counter; invalid = the org-level counter. The
// caller stores the scope on the reservation so the credit-back paths
// hit the same counter.
func lockDebitCounter(
	ctx context.Context,
	q counterScopeQuerier,
	sub db.GetActiveSubscriptionByOrgRow,
	therapistID pgtype.UUID,
) (db.UsageCounter, pgtype.UUID, error) {
	if therapistID.Valid {
		c, err := q.LockActiveCounterForTherapist(ctx, db.LockActiveCounterForTherapistParams{
			SubscriptionID: sub.ID,
			TherapistID:    therapistID,
		})
		if err == nil {
			return c, therapistID, nil
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return db.UsageCounter{}, pgtype.UUID{}, err
		}

		// No counter this period — mint one iff the therapist holds an
		// open seat in THIS org. Safe under the subscription advisory
		// lock; the partial unique index absorbs any cross-org race.
		seat, serr := q.GetSeatPlanForTherapist(ctx, uuid.UUID(therapistID.Bytes))
		switch {
		case serr == nil && seat.OrganizationID == sub.OrganizationID:
			c, cerr := q.CreateTherapistUsageCounter(ctx, db.CreateTherapistUsageCounterParams{
				SubscriptionID: sub.ID,
				TherapistID:    therapistID,
				PeriodStart:    sub.CurrentPeriodStart,
				PeriodEnd:      sub.CurrentPeriodEnd,
				TokensLimit:    seat.TokensPerPeriod,
			})
			if cerr == nil {
				return c, therapistID, nil
			}
			// CreateTherapistUsageCounter is ON CONFLICT DO NOTHING, so a
			// concurrent mint that already inserted the row returns no row
			// → pgx.ErrNoRows (NOT a 23505, which would have aborted this
			// tx and broken the re-lock below). Re-lock the winner's row.
			if errors.Is(cerr, pgx.ErrNoRows) {
				c2, e2 := q.LockActiveCounterForTherapist(ctx, db.LockActiveCounterForTherapistParams{
					SubscriptionID: sub.ID,
					TherapistID:    therapistID,
				})
				if e2 == nil {
					return c2, therapistID, nil
				}
			}
			return db.UsageCounter{}, pgtype.UUID{}, cerr
		case serr != nil && !errors.Is(serr, pgx.ErrNoRows):
			return db.UsageCounter{}, pgtype.UUID{}, serr
		}
		// Seatless (or seat in another org — anomalous): fall through to
		// the org-level counter, the pre-docs/38 behaviour.
	}

	c, err := q.LockActiveCounter(ctx, sub.ID)
	return c, pgtype.UUID{}, err
}

// lockScopedCounter locks the counter for an ALREADY-KNOWN scope — the
// credit-back paths (ReleaseCredit, CommitUsage-with-reservation,
// expiry cron) where pending_reservations.therapist_id says which
// counter was debited. No lazy minting here: if the scope's counter is
// gone (period rolled), callers keep their existing defensive handling.
func lockScopedCounter(
	ctx context.Context,
	q counterScopeQuerier,
	subscriptionID uuid.UUID,
	therapistID pgtype.UUID,
) (db.UsageCounter, error) {
	if therapistID.Valid {
		return q.LockActiveCounterForTherapist(ctx, db.LockActiveCounterForTherapistParams{
			SubscriptionID: subscriptionID,
			TherapistID:    therapistID,
		})
	}
	return q.LockActiveCounter(ctx, subscriptionID)
}

// parseOptionalTherapistID maps the request's therapist_id ("" = unset)
// to a pgtype.UUID. Invalid non-empty input is an error — a malformed
// ID must not silently demote enforcement to the org-level counter.
func parseOptionalTherapistID(raw string) (pgtype.UUID, error) {
	if raw == "" {
		return pgtype.UUID{}, nil
	}
	tid, err := parseUUID("therapist_id", raw)
	if err != nil {
		return pgtype.UUID{}, err
	}
	return pgtype.UUID{Bytes: tid, Valid: true}, nil
}
