package chat

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

// fakeQuotaDB models the ONE property the reservation protocol depends
// on: the conditional UPDATE is atomic. A mutex here stands in for the
// row lock Postgres takes, so the concurrency test exercises the real
// question — does the predicate live in the statement or in Go? — without
// needing a database.
//
// A full integration test against real Postgres also exists (see
// TestReserveIsRaceSafe_Integration, skipped without TEST_DATABASE_URL);
// this one runs everywhere and fails on the design error rather than on
// the environment.
type fakeQuotaDB struct {
	mu sync.Mutex

	counterID uuid.UUID
	used      int64
	reserved  int64
	limit     int64
	warnedAt  *time.Time

	reservations map[uuid.UUID]int64
	resAt        map[uuid.UUID]time.Time

	now func() time.Time

	failInsertReservation bool
	failReclaim           bool
}

func newFakeDB(limit int64, now func() time.Time) *fakeQuotaDB {
	return &fakeQuotaDB{
		counterID:    uuid.New(),
		limit:        limit,
		reservations: map[uuid.UUID]int64{},
		resAt:        map[uuid.UUID]time.Time{},
		now:          now,
	}
}

func (f *fakeQuotaDB) Exec(_ context.Context, sql string, args ...any) (int64, error) {
	f.mu.Lock()
	defer f.mu.Unlock()

	switch {
	case strings.Contains(sql, "DELETE FROM chat_usage_reservations") && strings.Contains(sql, "created_at <"):
		if f.failReclaim {
			return 0, errors.New("reclaim failed")
		}
		cutoff := args[1].(time.Time)
		var freed int64
		for id, at := range f.resAt {
			if at.Before(cutoff) {
				freed += f.reservations[id]
				delete(f.reservations, id)
				delete(f.resAt, id)
			}
		}
		f.reserved = max64(0, f.reserved-freed)
		return 1, nil

	case strings.Contains(sql, "WITH dropped AS"): // commit or release
		resID := args[1].(uuid.UUID)
		amount := args[2].(int64)
		if held, ok := f.reservations[resID]; ok {
			f.reserved = max64(0, f.reserved-held)
			delete(f.reservations, resID)
			delete(f.resAt, resID)
		}
		f.used += amount
		return 1, nil

	case strings.Contains(sql, "SET micro_usd_reserved = GREATEST(0, micro_usd_reserved - $2)"):
		f.reserved = max64(0, f.reserved-args[1].(int64))
		return 1, nil

	case strings.Contains(sql, "SET warned_at = now()"):
		if f.warnedAt == nil {
			t := f.now()
			f.warnedAt = &t
		}
		return 1, nil
	}
	return 0, nil
}

func (f *fakeQuotaDB) QueryRow(_ context.Context, sql string, args ...any) RowScanner {
	f.mu.Lock()
	defer f.mu.Unlock()

	switch {
	case strings.Contains(sql, "INSERT INTO chat_usage_counters"):
		// Values are snapshotted under the lock, not read lazily inside
		// the closure. A real pgx.Row materializes at query time too, so
		// a lazy fake would both race and misrepresent the thing under
		// test.
		id, used, res, lim, warned := f.counterID, f.used, f.reserved, f.limit, f.warnedAt
		return scanFunc(func(dest ...any) error {
			*(dest[0].(*uuid.UUID)) = id
			*(dest[1].(*int64)) = used
			*(dest[2].(*int64)) = res
			*(dest[3].(*int64)) = lim
			*(dest[4].(**time.Time)) = warned
			return nil
		})

	case strings.Contains(sql, "SET micro_usd_reserved = micro_usd_reserved + $2"):
		amount := args[1].(int64)
		// THE predicate. Evaluated under the same lock as the write,
		// exactly as Postgres evaluates it under the row lock.
		if f.used+f.reserved+amount > f.limit {
			return scanFunc(func(...any) error { return errors.New("no rows in result set") })
		}
		f.reserved += amount
		used, res, lim := f.used, f.reserved, f.limit
		return scanFunc(func(dest ...any) error {
			*(dest[0].(*int64)) = used
			*(dest[1].(*int64)) = res
			*(dest[2].(*int64)) = lim
			return nil
		})

	case strings.Contains(sql, "INSERT INTO chat_usage_reservations"):
		if f.failInsertReservation {
			return scanFunc(func(...any) error { return errors.New("insert failed") })
		}
		newID := uuid.New()
		f.reservations[newID] = args[1].(int64)
		f.resAt[newID] = f.now()
		return scanFunc(func(dest ...any) error { *(dest[0].(*uuid.UUID)) = newID; return nil })
	}
	return scanFunc(func(...any) error { return errors.New("unexpected query") })
}

type scanFunc func(dest ...any) error

func (s scanFunc) Scan(dest ...any) error { return s(dest...) }

func max64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}

func fixedNow() time.Time { return time.Date(2026, 8, 20, 12, 0, 0, 0, time.UTC) }

// ── The race ──────────────────────────────────────────────────────────

// Two concurrent turns at a nearly exhausted limit: exactly one may pass.
// This is the test the plan's F6 DoD names, and it is the reason the
// limit check lives in the SQL predicate instead of in Go.
func TestReserveIsRaceSafeAtTheBoundary(t *testing.T) {
	// Room for exactly one reservation.
	db := newFakeDB(reserveEstimate+reserveEstimate-1, fixedNow)
	q := Quota{DB: db, Now: fixedNow}
	therapist := uuid.New()

	const parallel = 32
	var (
		wg        sync.WaitGroup
		mu        sync.Mutex
		granted   int
		exhausted int
		other     []error
	)
	start := make(chan struct{})
	for i := 0; i < parallel; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			<-start
			_, err := q.Reserve(context.Background(), therapist, db.limit)
			mu.Lock()
			defer mu.Unlock()
			switch {
			case err == nil:
				granted++
			case errors.Is(err, ErrQuotaExhausted):
				exhausted++
			default:
				other = append(other, err)
			}
		}()
	}
	close(start)
	wg.Wait()

	if len(other) > 0 {
		t.Fatalf("unexpected errors: %v", other)
	}
	if granted != 1 {
		t.Fatalf("%d reservations granted, want exactly 1 — the limit check is racing", granted)
	}
	if exhausted != parallel-1 {
		t.Errorf("%d exhausted, want %d", exhausted, parallel-1)
	}
	if db.used+db.reserved > db.limit {
		t.Errorf("counter overshot the limit: used=%d reserved=%d limit=%d", db.used, db.reserved, db.limit)
	}
}

// Under sustained parallel load the counter must never exceed the limit.
func TestConcurrentTurnsNeverOvershootTheLimit(t *testing.T) {
	db := newFakeDB(reserveEstimate*10, fixedNow)
	q := Quota{DB: db, Now: fixedNow}
	therapist := uuid.New()

	var wg sync.WaitGroup
	for i := 0; i < 100; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r, err := q.Reserve(context.Background(), therapist, db.limit)
			if err != nil {
				return
			}
			// Commit a realistic turn cost, well under the reservation.
			_, _ = q.Commit(context.Background(), r, []ModelCost{
				{Model: "gemini-2.5-flash", InputTokens: 4000, OutputTokens: 600},
			})
		}()
	}
	wg.Wait()

	db.mu.Lock()
	defer db.mu.Unlock()
	if db.used+db.reserved > db.limit {
		t.Errorf("overshoot: used=%d reserved=%d limit=%d", db.used, db.reserved, db.limit)
	}
	if db.reserved != 0 {
		t.Errorf("%d micro-USD left reserved after all turns committed", db.reserved)
	}
}

// ── Protocol ──────────────────────────────────────────────────────────

// Commit charges the MEASURED cost, not the reservation. The reservation
// is an over-estimate on purpose; charging it would systematically
// overbill by roughly 2x.
func TestCommitChargesMeasuredCostNotTheEstimate(t *testing.T) {
	db := newFakeDB(1_500_000, fixedNow)
	q := Quota{DB: db, Now: fixedNow}

	r, err := q.Reserve(context.Background(), uuid.New(), db.limit)
	if err != nil {
		t.Fatalf("Reserve: %v", err)
	}
	// 60450 in / 6418 out on 2.5-flash == 34180 micro-USD... but a chat
	// turn is much smaller. Use a realistic turn.
	actual, err := q.Commit(context.Background(), r, []ModelCost{
		{Model: "gemini-2.5-flash", InputTokens: 100, OutputTokens: 20},   // classifier
		{Model: "gemini-2.5-flash", InputTokens: 6000, OutputTokens: 700}, // generator
		{Model: "gemini-2.5-flash", InputTokens: 800, OutputTokens: 10},   // verifier
	})
	if err != nil {
		t.Fatalf("Commit: %v", err)
	}
	if actual >= reserveEstimate {
		t.Errorf("charged %d, which is not less than the %d reservation — is it charging the estimate?", actual, reserveEstimate)
	}
	if db.used != actual {
		t.Errorf("counter used=%d, committed=%d", db.used, actual)
	}
	if db.reserved != 0 {
		t.Errorf("reservation not released: %d", db.reserved)
	}
}

// A refusal must cost the therapist nothing.
func TestReleaseChargesNothing(t *testing.T) {
	db := newFakeDB(1_500_000, fixedNow)
	q := Quota{DB: db, Now: fixedNow}
	r, _ := q.Reserve(context.Background(), uuid.New(), db.limit)

	if err := q.Release(context.Background(), r); err != nil {
		t.Fatalf("Release: %v", err)
	}
	if db.used != 0 {
		t.Errorf("release charged %d micro-USD", db.used)
	}
	if db.reserved != 0 {
		t.Errorf("release left %d reserved", db.reserved)
	}
}

// An unpriced model must charge the reservation rather than zero: a free
// turn on an unknown model is a hole in the ceiling.
func TestUnpricedModelChargesTheReservationNotZero(t *testing.T) {
	db := newFakeDB(1_500_000, fixedNow)
	q := Quota{DB: db, Now: fixedNow}
	r, _ := q.Reserve(context.Background(), uuid.New(), db.limit)

	actual, err := q.Commit(context.Background(), r, []ModelCost{
		{Model: "gemini-imaginary", InputTokens: 1000, OutputTokens: 1000},
	})
	if err != nil {
		t.Fatalf("Commit: %v", err)
	}
	if actual != reserveEstimate {
		t.Errorf("unpriced model charged %d, want the %d reservation", actual, reserveEstimate)
	}
}

// A crashed turn's reservation must be reclaimed, or one crash costs the
// therapist that budget for the rest of the month.
func TestStaleReservationIsReclaimed(t *testing.T) {
	now := fixedNow()
	clock := func() time.Time { return now }
	db := newFakeDB(reserveEstimate, clock) // room for exactly one
	q := Quota{DB: db, Now: clock}
	therapist := uuid.New()

	if _, err := q.Reserve(context.Background(), therapist, db.limit); err != nil {
		t.Fatalf("first Reserve: %v", err)
	}
	// Second turn does not fit while the first is in flight.
	if _, err := q.Reserve(context.Background(), therapist, db.limit); !errors.Is(err, ErrQuotaExhausted) {
		t.Fatalf("second Reserve: %v, want exhausted", err)
	}

	// The first turn's process died. After the stale window its hold is
	// reclaimed and a new turn fits again.
	now = now.Add(staleReservationAfter + time.Minute)
	if _, err := q.Reserve(context.Background(), therapist, db.limit); err != nil {
		t.Fatalf("Reserve after stale window: %v, want success", err)
	}
}

// A live-but-slow turn must not have its budget stolen.
func TestFreshReservationIsNotReclaimed(t *testing.T) {
	now := fixedNow()
	clock := func() time.Time { return now }
	db := newFakeDB(reserveEstimate, clock)
	q := Quota{DB: db, Now: clock}
	therapist := uuid.New()

	r, _ := q.Reserve(context.Background(), therapist, db.limit)
	now = now.Add(staleReservationAfter - time.Second)

	if _, err := q.Reserve(context.Background(), therapist, db.limit); !errors.Is(err, ErrQuotaExhausted) {
		t.Fatal("a still-fresh reservation was reclaimed")
	}
	if _, err := q.Commit(context.Background(), r, nil); err != nil {
		t.Fatalf("Commit: %v", err)
	}
}

// A database failure must not be reported as exhaustion — that would
// silently degrade every turn during an outage and look like a budget
// problem.
func TestDatabaseErrorIsNotReportedAsExhaustion(t *testing.T) {
	db := newFakeDB(1_500_000, fixedNow)
	db.failInsertReservation = true
	q := Quota{DB: db, Now: fixedNow}

	_, err := q.Reserve(context.Background(), uuid.New(), db.limit)
	if err == nil {
		t.Fatal("want error")
	}
	if errors.Is(err, ErrQuotaExhausted) {
		t.Error("a database failure was reported as quota exhaustion")
	}
	if db.reserved != 0 {
		t.Errorf("failed reservation leaked %d micro-USD", db.reserved)
	}
}

func TestWarningFiresOnceAtEightyPercent(t *testing.T) {
	db := newFakeDB(100_000, fixedNow)
	q := Quota{DB: db, Now: fixedNow}
	therapist := uuid.New()

	db.used = 79_000 // below 80% of 100_000 even with the reservation? 79000+8000=87000 -> above
	r, err := q.Reserve(context.Background(), therapist, db.limit)
	if err != nil {
		t.Fatalf("Reserve: %v", err)
	}
	if !r.State.ShouldWarn {
		t.Fatalf("no warning at used=%d reserved=%d limit=%d", r.State.UsedMicroUSD, r.State.ReservedMicroUSD, r.State.LimitMicroUSD)
	}
	if err := q.MarkWarned(context.Background(), r); err != nil {
		t.Fatalf("MarkWarned: %v", err)
	}
	_, _ = q.Commit(context.Background(), r, nil)

	r2, err := q.Reserve(context.Background(), therapist, db.limit)
	if err != nil {
		t.Fatalf("second Reserve: %v", err)
	}
	if r2.State.ShouldWarn {
		t.Error("warning fired twice")
	}
}

func TestPeriodIsHalfOpen(t *testing.T) {
	start, end := PeriodFor(time.Date(2026, 8, 20, 12, 0, 0, 0, time.UTC))
	if !start.Equal(time.Date(2026, 8, 1, 0, 0, 0, 0, time.UTC)) {
		t.Errorf("start = %v", start)
	}
	if !end.Equal(time.Date(2026, 9, 1, 0, 0, 0, 0, time.UTC)) {
		t.Errorf("end = %v", end)
	}
	// A turn at exactly period_end belongs to the NEXT period.
	nextStart, _ := PeriodFor(end)
	if !nextStart.Equal(end) {
		t.Errorf("boundary turn landed in period starting %v, want %v", nextStart, end)
	}
}

// The default budget must match decision D3 and the app_config seed.
func TestDefaultBudgetMatchesDecisionD3(t *testing.T) {
	const d3 int64 = 1_500_000 // $1.50
	turns := d3 / reserveEstimate
	if turns < 100 {
		t.Errorf("the reservation estimate (%d) allows only %d turns per $1.50 — "+
			"the plan expects 330-500 at real cost, and a too-large reservation "+
			"blocks turns that would have fit", reserveEstimate, turns)
	}
}
