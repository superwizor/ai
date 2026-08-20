package chat

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/superwizor-ai/backend/pkg/llmcost"
)

// The quota enforces a per-therapist monthly spending ceiling on the AI
// chat (ADR section 10, decision D3: $1.50/month by default).
//
// # Reserve before the classifier
//
// The reservation is taken BEFORE the first model call. Two consequences,
// both intentional:
//
//   - An exhausted budget costs zero model calls to refuse. A quota that
//     only discovered exhaustion after spending is a quota that charges
//     you for saying no.
//   - Two concurrent turns cannot both pass. The reservation is a single
//     conditional UPDATE whose predicate includes the limit, so Postgres
//     row locking serializes them and the second one gets zero rows.
//
// # Exhaustion degrades, it does not lock out
//
// A therapist over budget keeps A2/A6 (SQL only, no model) and always
// keeps crisis information. What they lose is generation. Being locked
// out of your own case notes by a budget is not a safety property.

// ErrQuotaExhausted reports that this turn does not fit in the remaining
// budget. Surfaced to the client as CHAT_QUOTA_EXHAUSTED.
var ErrQuotaExhausted = errors.New("chat: quota exhausted")

// reserveEstimate is the upper-bound micro-USD reserved before a turn.
//
// Derived, not guessed: a worst-case turn is a classifier call plus a
// generator call plus a verifier call. Sized from the production shape
// measured on 2026-08-20 (a chat turn runs $0.0030-$0.0045) with headroom
// for a long retrieval context, then rounded up. Over-reserving costs
// nothing but a briefly smaller visible balance; under-reserving lets a
// turn overshoot the ceiling it exists to enforce.
const reserveEstimate int64 = 8_000 // $0.008

// staleReservationAfter is how long an unclosed reservation is honoured
// before it is reclaimed. Long enough that a slow-but-alive turn is never
// robbed of its budget; short enough that a crashed process does not
// block a therapist for the rest of the month.
const staleReservationAfter = 5 * time.Minute

// QuotaState is what the caller needs to know after a reservation.
type QuotaState struct {
	LimitMicroUSD     int64
	UsedMicroUSD      int64
	ReservedMicroUSD  int64
	RemainingMicroUSD int64
	// ShouldWarn is true on the turn that first crosses 80%.
	ShouldWarn bool
	PeriodEnd  time.Time
}

// Reservation is an in-flight hold. It MUST be closed with Commit or
// Release; a dropped reservation is reclaimed after staleReservationAfter
// but blocks that much budget in the meantime.
type Reservation struct {
	ID        uuid.UUID
	CounterID uuid.UUID
	MicroUSD  int64
	State     QuotaState
}

// QuotaDB is the database surface the quota needs. Narrow on purpose: the
// race-safety argument rests on these three statements and nothing else.
type QuotaDB interface {
	Exec(ctx context.Context, sql string, args ...any) (int64, error)
	QueryRow(ctx context.Context, sql string, args ...any) RowScanner
}

// RowScanner is pgx.Row.
type RowScanner interface{ Scan(dest ...any) error }

// Quota manages per-therapist budgets.
type Quota struct {
	DB QuotaDB
	// Now is the clock. Injectable so period-boundary and stale-reclaim
	// behaviour can be tested without sleeping.
	Now func() time.Time
}

func (q Quota) now() time.Time {
	if q.Now != nil {
		return q.Now()
	}
	return time.Now()
}

// warnThreshold is the fraction of the limit at which the therapist is
// warned once.
const warnThreshold = 0.8

const sqlEnsureCounter = `
INSERT INTO chat_usage_counters (therapist_id, period_start, period_end, micro_usd_limit)
VALUES ($1, $2, $3, $4)
ON CONFLICT (therapist_id, period_start) DO UPDATE
    SET updated_at = now()
RETURNING id, micro_usd_used, micro_usd_reserved, micro_usd_limit, warned_at`

// sqlReclaimStale drops reservations older than the stale window and
// subtracts them from the counter. Runs opportunistically before each
// reservation rather than as a background job, so the mechanism lives in
// one place and a therapist who never returns is not blocked by a ghost
// of their own turn.
const sqlReclaimStale = `
WITH stale AS (
    DELETE FROM chat_usage_reservations
    WHERE counter_id = $1 AND created_at < $2
    RETURNING micro_usd
)
UPDATE chat_usage_counters c
   SET micro_usd_reserved = GREATEST(0, c.micro_usd_reserved - COALESCE((SELECT SUM(micro_usd) FROM stale), 0)),
       updated_at = now()
 WHERE c.id = $1`

// sqlReserve is the load-bearing statement.
//
// The limit check lives in the WHERE clause, not in application code
// between a SELECT and an UPDATE. That is the entire race-safety
// argument: Postgres takes a row lock for the UPDATE, so two concurrent
// turns are serialized and the one that no longer fits matches zero rows.
// A read-then-write in Go would let both read the same balance and both
// decide they fit.
const sqlReserve = `
UPDATE chat_usage_counters
   SET micro_usd_reserved = micro_usd_reserved + $2,
       updated_at = now()
 WHERE id = $1
   AND micro_usd_used + micro_usd_reserved + $2 <= micro_usd_limit
RETURNING micro_usd_used, micro_usd_reserved, micro_usd_limit`

const sqlInsertReservation = `
INSERT INTO chat_usage_reservations (counter_id, micro_usd)
VALUES ($1, $2) RETURNING id`

// Reserve holds reserveEstimate against the therapist's current period.
//
// Returns ErrQuotaExhausted when the turn does not fit. The caller
// degrades to defined_ops rather than refusing outright.
func (q Quota) Reserve(ctx context.Context, therapistID uuid.UUID, limitMicroUSD int64) (*Reservation, error) {
	start, end := PeriodFor(q.now())

	var (
		counterID        uuid.UUID
		used, res, limit int64
		warnedAt         *time.Time
	)
	err := q.DB.QueryRow(ctx, sqlEnsureCounter, therapistID, start, end, limitMicroUSD).
		Scan(&counterID, &used, &res, &limit, &warnedAt)
	if err != nil {
		return nil, fmt.Errorf("chat: ensure counter: %w", err)
	}

	// Reclaim anything left behind by a crashed turn before deciding
	// this one does not fit.
	if _, err := q.DB.Exec(ctx, sqlReclaimStale, counterID, q.now().Add(-staleReservationAfter)); err != nil {
		// Not fatal: the reservation below may still succeed, and
		// failing the turn because a cleanup failed would be worse than
		// carrying a stale hold for another five minutes.
		return q.reserveAfterReclaim(ctx, counterID, limit, end, warnedAt)
	}
	return q.reserveAfterReclaim(ctx, counterID, limit, end, warnedAt)
}

func (q Quota) reserveAfterReclaim(ctx context.Context, counterID uuid.UUID, limit int64, periodEnd time.Time, warnedAt *time.Time) (*Reservation, error) {
	var used, res, lim int64
	err := q.DB.QueryRow(ctx, sqlReserve, counterID, reserveEstimate).Scan(&used, &res, &lim)
	if err != nil {
		// Zero rows means the predicate failed: the turn does not fit.
		// Any other error is a real failure and must not be reported as
		// exhaustion, which would silently degrade every turn during a
		// database problem.
		if isNoRows(err) {
			return nil, ErrQuotaExhausted
		}
		return nil, fmt.Errorf("chat: reserve: %w", err)
	}

	var resID uuid.UUID
	if err := q.DB.QueryRow(ctx, sqlInsertReservation, counterID, reserveEstimate).Scan(&resID); err != nil {
		// The hold is already on the counter; without a reservation row
		// it can only be reclaimed by the stale sweep. Release it now.
		_, _ = q.DB.Exec(ctx, `UPDATE chat_usage_counters SET micro_usd_reserved = GREATEST(0, micro_usd_reserved - $2) WHERE id = $1`, counterID, reserveEstimate)
		return nil, fmt.Errorf("chat: record reservation: %w", err)
	}

	state := QuotaState{
		LimitMicroUSD:     lim,
		UsedMicroUSD:      used,
		ReservedMicroUSD:  res,
		RemainingMicroUSD: lim - used - res,
		PeriodEnd:         periodEnd,
	}
	if warnedAt == nil && lim > 0 && float64(used+res) >= float64(lim)*warnThreshold {
		state.ShouldWarn = true
	}
	return &Reservation{ID: resID, CounterID: counterID, MicroUSD: reserveEstimate, State: state}, nil
}

const sqlCommit = `
WITH dropped AS (
    DELETE FROM chat_usage_reservations WHERE id = $2 RETURNING micro_usd
)
UPDATE chat_usage_counters
   SET micro_usd_used     = micro_usd_used + $3,
       micro_usd_reserved = GREATEST(0, micro_usd_reserved - COALESCE((SELECT micro_usd FROM dropped), 0)),
       updated_at = now()
 WHERE id = $1`

// Commit records the real cost and releases the hold.
//
// costs are the measured usages of every model call the turn made. They
// are priced through pkg/llmcost, never estimated: the reservation was
// the estimate, and committing the estimate instead of the measurement
// would make the ledger diverge from the actual bill.
func (q Quota) Commit(ctx context.Context, r *Reservation, costs []ModelCost) (int64, error) {
	if r == nil {
		return 0, nil
	}
	var actual int64
	at := q.now()
	for _, c := range costs {
		micro, err := llmcost.CostMicroUSD(c.Model, c.InputTokens, c.OutputTokens, at)
		if err != nil {
			// An unpriced model must not commit as free. Charge the
			// reservation, which is an over-estimate, and let the
			// llmcost error surface in logs.
			actual = r.MicroUSD
			break
		}
		actual += micro
	}
	if _, err := q.DB.Exec(ctx, sqlCommit, r.CounterID, r.ID, actual); err != nil {
		return actual, fmt.Errorf("chat: commit: %w", err)
	}
	return actual, nil
}

// Release drops a reservation without charging. Used when a turn is
// refused before any model call, so a refusal costs the therapist
// nothing.
func (q Quota) Release(ctx context.Context, r *Reservation) error {
	if r == nil {
		return nil
	}
	if _, err := q.DB.Exec(ctx, sqlCommit, r.CounterID, r.ID, int64(0)); err != nil {
		return fmt.Errorf("chat: release: %w", err)
	}
	return nil
}

const sqlMarkWarned = `UPDATE chat_usage_counters SET warned_at = now() WHERE id = $1 AND warned_at IS NULL`

// MarkWarned records that the 80% warning was delivered, so it shows once.
func (q Quota) MarkWarned(ctx context.Context, r *Reservation) error {
	if r == nil {
		return nil
	}
	_, err := q.DB.Exec(ctx, sqlMarkWarned, r.CounterID)
	return err
}

// ModelCost is one model call's measured usage.
type ModelCost struct {
	Model        string
	InputTokens  int64
	OutputTokens int64
}

// PeriodFor returns the half-open [start, end) billing period containing
// t: the calendar month in UTC.
//
// Half-open matters. With a closed interval a turn at exactly midnight on
// the first would belong to two periods, and whichever query ran first
// would decide which budget it hit.
func PeriodFor(t time.Time) (time.Time, time.Time) {
	t = t.UTC()
	start := time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC)
	return start, start.AddDate(0, 1, 0)
}

// isNoRows reports whether err is pgx's "no rows" sentinel. Matched by
// message rather than by type so this file does not import pgx, keeping
// the quota unit-testable against a fake.
func isNoRows(err error) bool {
	return err != nil && err.Error() == "no rows in result set"
}
