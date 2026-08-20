package appconfig

import (
	"context"
	"errors"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

// ── fake Querier ──────────────────────────────────────────────────────

type row struct {
	key, value string
	org        *uuid.UUID
}

type fakeDB struct {
	mu      sync.Mutex
	rows    []row
	calls   int
	failNow bool
}

func (f *fakeDB) Query(_ context.Context, _ string, _ ...any) (Rows, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.calls++
	if f.failNow {
		return nil, errors.New("db down")
	}
	cp := make([]row, len(f.rows))
	copy(cp, f.rows)
	return &fakeRows{rows: cp}, nil
}

func (f *fakeDB) set(rows []row) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.rows = rows
}

func (f *fakeDB) callCount() int {
	f.mu.Lock()
	defer f.mu.Unlock()
	return f.calls
}

type fakeRows struct {
	rows []row
	i    int
}

func (r *fakeRows) Next() bool { r.i++; return r.i <= len(r.rows) }
func (r *fakeRows) Scan(dest ...any) error {
	cur := r.rows[r.i-1]
	*(dest[0].(*string)) = cur.key
	*(dest[1].(*string)) = cur.value
	*(dest[2].(**uuid.UUID)) = cur.org
	return nil
}
func (r *fakeRows) Err() error { return nil }
func (r *fakeRows) Close()     {}

// ── tests ─────────────────────────────────────────────────────────────

func TestDefaultsAreSafeWhenTableIsEmpty(t *testing.T) {
	r := NewReader(&fakeDB{})
	ctx := context.Background()

	if r.ChatEnabled(ctx, uuid.Nil) {
		t.Error("empty table must leave chat DISABLED")
	}
	if got := r.ChatMode(ctx, uuid.Nil); got != ModeDefinedOps {
		t.Errorf("empty table mode = %q, want %q (restricted)", got, ModeDefinedOps)
	}
}

// A nil Querier (local dev, unit tests) must not panic and must yield the
// safe defaults.
func TestNilQuerierYieldsDefaults(t *testing.T) {
	r := NewReader(nil)
	ctx := context.Background()
	if r.ChatEnabled(ctx, uuid.Nil) {
		t.Error("nil querier must leave chat disabled")
	}
	if got := r.Int64(ctx, KeyAIChatQuotaMicroUSD, uuid.Nil); got != 1_500_000 {
		t.Errorf("quota default = %d, want 1500000", got)
	}
}

func TestGlobalValueIsRead(t *testing.T) {
	db := &fakeDB{rows: []row{{key: KeyAIChatEnabled, value: "true"}}}
	r := NewReader(db)
	if !r.ChatEnabled(context.Background(), uuid.Nil) {
		t.Error("global row not honoured")
	}
}

func TestOrgOverrideBeatsGlobal(t *testing.T) {
	org := uuid.New()
	other := uuid.New()
	db := &fakeDB{rows: []row{
		{key: KeyAIChatMode, value: ModeFull},
		{key: KeyAIChatMode, value: ModeDefinedOps, org: &org},
	}}
	r := NewReader(db)
	ctx := context.Background()

	if got := r.ChatMode(ctx, org); got != ModeDefinedOps {
		t.Errorf("override org: got %q, want %q", got, ModeDefinedOps)
	}
	if got := r.ChatMode(ctx, other); got != ModeFull {
		t.Errorf("non-override org: got %q, want %q (global)", got, ModeFull)
	}
	if got := r.ChatMode(ctx, uuid.Nil); got != ModeFull {
		t.Errorf("global scope: got %q, want %q", got, ModeFull)
	}
}

// The cache must actually cache: repeated reads inside the TTL hit the
// database once.
func TestCacheHitsDatabaseOncePerTTL(t *testing.T) {
	db := &fakeDB{rows: []row{{key: KeyAIChatEnabled, value: "true"}}}
	now := time.Unix(1_700_000_000, 0)
	r := NewReader(db).WithTTL(30 * time.Second).withClock(func() time.Time { return now })
	ctx := context.Background()

	for i := 0; i < 10; i++ {
		r.ChatEnabled(ctx, uuid.Nil)
	}
	if db.callCount() != 1 {
		t.Fatalf("queries inside TTL = %d, want 1", db.callCount())
	}

	// A change is invisible until the TTL expires...
	db.set([]row{{key: KeyAIChatEnabled, value: "false"}})
	if !r.ChatEnabled(ctx, uuid.Nil) {
		t.Error("value changed before TTL expiry — cache not holding")
	}

	// ...and visible immediately after.
	now = now.Add(31 * time.Second)
	if r.ChatEnabled(ctx, uuid.Nil) {
		t.Error("value did not refresh after TTL expiry")
	}
	if db.callCount() != 2 {
		t.Errorf("queries after expiry = %d, want 2", db.callCount())
	}
}

// Propagation bound is the contract the kill-switch runbook depends on:
// a flip must be visible within DefaultTTL, well inside the ADR's 5 min
// target and 1 h requirement.
func TestKillSwitchPropagatesWithinTTL(t *testing.T) {
	db := &fakeDB{rows: []row{{key: KeyAIChatEnabled, value: "true"}}}
	now := time.Unix(1_700_000_000, 0)
	r := NewReader(db).withClock(func() time.Time { return now })
	ctx := context.Background()

	if !r.ChatEnabled(ctx, uuid.Nil) {
		t.Fatal("precondition: chat should start enabled")
	}
	db.set([]row{{key: KeyAIChatEnabled, value: "false"}}) // operator flips

	now = now.Add(DefaultTTL)
	if r.ChatEnabled(ctx, uuid.Nil) {
		t.Fatalf("kill switch not effective after %s", DefaultTTL)
	}
	if DefaultTTL > 5*time.Minute {
		t.Errorf("DefaultTTL %s exceeds the 5 min target from ADR section 11", DefaultTTL)
	}
}

// Refresh bypasses the TTL so the runbook can confirm propagation.
func TestRefreshBypassesTTL(t *testing.T) {
	db := &fakeDB{rows: []row{{key: KeyAIChatEnabled, value: "true"}}}
	now := time.Unix(1_700_000_000, 0)
	r := NewReader(db).withClock(func() time.Time { return now })
	ctx := context.Background()
	r.ChatEnabled(ctx, uuid.Nil)

	db.set([]row{{key: KeyAIChatEnabled, value: "false"}})
	if err := r.Refresh(ctx); err != nil {
		t.Fatalf("Refresh: %v", err)
	}
	if r.ChatEnabled(ctx, uuid.Nil) {
		t.Error("Refresh did not pick up the new value")
	}
}

// A database outage must not revert a deliberate operator setting; the
// last good snapshot is served stale.
func TestStaleSnapshotSurvivesDatabaseOutage(t *testing.T) {
	db := &fakeDB{rows: []row{{key: KeyAIChatMode, value: ModeFull}}}
	now := time.Unix(1_700_000_000, 0)
	r := NewReader(db).withClock(func() time.Time { return now })
	ctx := context.Background()

	if got := r.ChatMode(ctx, uuid.Nil); got != ModeFull {
		t.Fatalf("precondition: got %q", got)
	}

	db.mu.Lock()
	db.failNow = true
	db.mu.Unlock()
	now = now.Add(time.Hour)

	if got := r.ChatMode(ctx, uuid.Nil); got != ModeFull {
		t.Errorf("outage reverted the setting to %q; want the stale %q", got, ModeFull)
	}
}

// Cold start with no snapshot AND a dead database must fail closed.
func TestColdStartWithDeadDatabaseFailsClosed(t *testing.T) {
	db := &fakeDB{failNow: true}
	r := NewReader(db)
	ctx := context.Background()

	if r.ChatEnabled(ctx, uuid.Nil) {
		t.Error("cold start with dead DB must leave chat disabled")
	}
	if got := r.ChatMode(ctx, uuid.Nil); got != ModeDefinedOps {
		t.Errorf("cold start mode = %q, want %q", got, ModeDefinedOps)
	}
}

// An operator typo must never widen behaviour.
func TestGarbageValuesFallBackToSafeDefaults(t *testing.T) {
	db := &fakeDB{rows: []row{
		{key: KeyAIChatEnabled, value: "ture"},
		{key: KeyAIChatMode, value: "unrestricted"},
		{key: KeyAIChatQuotaMicroUSD, value: "1.5 USD"},
		{key: KeyAIChatClassifierTau, value: "high"},
	}}
	r := NewReader(db)
	ctx := context.Background()

	if r.ChatEnabled(ctx, uuid.Nil) {
		t.Error(`"ture" must read as the default false, not true`)
	}
	if got := r.ChatMode(ctx, uuid.Nil); got != ModeDefinedOps {
		t.Errorf("unknown mode = %q, want %q", got, ModeDefinedOps)
	}
	if got := r.Int64(ctx, KeyAIChatQuotaMicroUSD, uuid.Nil); got != 1_500_000 {
		t.Errorf("garbage quota = %d, want default 1500000", got)
	}
	if got := r.Float64(ctx, KeyAIChatClassifierTau, uuid.Nil); got != 0.85 {
		t.Errorf("garbage tau = %v, want default 0.85", got)
	}
}

func TestTypedReads(t *testing.T) {
	db := &fakeDB{rows: []row{
		{key: KeyAIChatQuotaMicroUSD, value: "2500000"},
		{key: KeyAIChatClassifierTau, value: "0.9"},
	}}
	r := NewReader(db)
	ctx := context.Background()

	if got := r.Int64(ctx, KeyAIChatQuotaMicroUSD, uuid.Nil); got != 2_500_000 {
		t.Errorf("Int64 = %d", got)
	}
	if got := r.Float64(ctx, KeyAIChatClassifierTau, uuid.Nil); got != 0.9 {
		t.Errorf("Float64 = %v", got)
	}
}

// Concurrent expiry must collapse into a single refresh, not one query
// per in-flight request.
func TestConcurrentRefreshQueriesOnce(t *testing.T) {
	db := &fakeDB{rows: []row{{key: KeyAIChatEnabled, value: "true"}}}
	r := NewReader(db)
	ctx := context.Background()

	var wg sync.WaitGroup
	for i := 0; i < 50; i++ {
		wg.Add(1)
		go func() { defer wg.Done(); r.ChatEnabled(ctx, uuid.Nil) }()
	}
	wg.Wait()

	if n := db.callCount(); n != 1 {
		t.Errorf("50 concurrent cold reads issued %d queries, want 1", n)
	}
}

// Every declared key must have a default; a key without one silently
// returns "" at runtime.
func TestEveryDeclaredKeyHasADefault(t *testing.T) {
	for _, k := range []string{KeyAIChatEnabled, KeyAIChatMode, KeyAIChatClassifierTau, KeyAIChatQuotaMicroUSD} {
		if _, ok := Default(k); !ok {
			t.Errorf("key %q has no compiled-in default", k)
		}
	}
}
