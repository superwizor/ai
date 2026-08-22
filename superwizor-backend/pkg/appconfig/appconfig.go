// Package appconfig reads runtime configuration from the app_config table
// (migration 000084) with a short in-process cache.
//
// # Why this exists
//
// The AI chat kill switch has a hard requirement: a change must take
// effect in under an hour, targeting under five minutes (ADR
// docs/kronikarz/62 section 11). Environment variables cannot meet it —
// changing one means a Cloud Run deploy, which is slowest precisely when
// the platform is unhealthy. A table row plus a 30-second cache bounds
// propagation at the TTL.
//
// # Failure posture
//
// Every lookup falls back to a compiled-in default, and the defaults are
// the SAFE values, not the convenient ones: chat disabled, mode restricted.
// A database outage therefore turns the chat off rather than leaving it
// running unconfigured. The same applies to an unparseable value: a
// typo'd 'ture' in AI_CHAT_ENABLED reads as the default (false) and is
// logged, never as true.
//
// This asymmetry is deliberate and is why Bool takes no "default if
// missing" argument at the call site — the safe default belongs to the
// key, declared once in defaults, not to whoever happens to read it.
package appconfig

import (
	"context"
	"log/slog"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/google/uuid"
)

// Keys read by the platform. Every key used anywhere must be declared
// here and given a default in defaults below — Get on an undeclared key
// returns the zero value and logs, which is a bug, not a feature.
const (
	KeyAIChatEnabled       = "AI_CHAT_ENABLED"
	KeyAIChatMode          = "AI_CHAT_MODE"
	KeyAIChatClassifierTau = "AI_CHAT_CLASSIFIER_TAU"
	KeyAIChatQuotaMicroUSD = "AI_CHAT_QUOTA_MICRO_USD"
)

// Chat modes for KeyAIChatMode.
const (
	// ModeFull enables every ALLOWED intent, including the generative
	// A8-A10.
	ModeFull = "full"
	// ModeDefinedOps restricts the chat to extractive operations:
	// A8-A10 are unavailable and degrade to A7/A2 (ADR section 11).
	ModeDefinedOps = "defined_ops"
)

// defaults are the compiled-in fallbacks, used when the row is missing,
// the value is unparseable, or the database is unreachable. They are the
// conservative end of every switch.
var defaults = map[string]string{
	KeyAIChatEnabled:       "false",
	KeyAIChatMode:          ModeDefinedOps,
	KeyAIChatClassifierTau: "0.85",
	KeyAIChatQuotaMicroUSD: "4000000",
}

// DefaultTTL bounds how stale a read can be, and therefore how long a
// kill-switch flip takes to reach every instance. 30 s sits inside the
// five-minute target with room for a slow rollout.
const DefaultTTL = 30 * time.Second

// Querier is the subset of pgxpool.Pool this package needs. Declared
// locally so the package does not depend on pgx: it keeps the module
// dependency-free and lets tests supply a plain fake.
type Querier interface {
	Query(ctx context.Context, sql string, args ...any) (Rows, error)
}

// Rows is the subset of pgx.Rows used here.
type Rows interface {
	Next() bool
	Scan(dest ...any) error
	Err() error
	Close()
}

// entry is one cached snapshot of the whole table.
type entry struct {
	// global maps key -> value for organization_id IS NULL.
	global map[string]string
	// byOrg maps organizationID -> key -> value.
	byOrg    map[uuid.UUID]map[string]string
	loadedAt time.Time
}

// Reader is a cached view of app_config. Safe for concurrent use.
//
// The whole table is loaded in one query rather than caching per key.
// The table holds a handful of rows, a single round trip is cheaper than
// N, and it makes the cache coherent: every key in one snapshot comes
// from the same instant, so a router cannot read AI_CHAT_ENABLED from
// before a change and AI_CHAT_MODE from after it.
type Reader struct {
	q   Querier
	ttl time.Duration
	now func() time.Time

	mu  sync.RWMutex
	cur *entry
	// loading serializes refreshes so a cache expiry under load produces
	// one query, not one per in-flight request.
	loading sync.Mutex
}

// NewReader builds a Reader over q. A nil Querier is allowed and makes
// every lookup return its default — used by unit tests and by local dev
// runs with no database.
func NewReader(q Querier) *Reader {
	return &Reader{q: q, ttl: DefaultTTL, now: time.Now}
}

// WithTTL overrides the cache TTL. Used by tests; production uses
// DefaultTTL.
func (r *Reader) WithTTL(d time.Duration) *Reader { r.ttl = d; return r }

// withClock overrides the clock. Test seam.
func (r *Reader) withClock(f func() time.Time) *Reader { r.now = f; return r }

const selectAll = `SELECT key, value, organization_id FROM app_config`

// snapshot returns a fresh-enough entry, refreshing if the TTL expired.
//
// On a refresh error the previous snapshot is kept and served stale. That
// is the right trade for a kill switch: a database blip must not revert a
// deliberate operator change back to the default, which for AI_CHAT_MODE
// would silently re-enable nothing but for a per-org override could
// change behaviour under the operator's feet. Only a cold start with no
// snapshot at all falls through to defaults.
func (r *Reader) snapshot(ctx context.Context) *entry {
	r.mu.RLock()
	cur := r.cur
	r.mu.RUnlock()

	if cur != nil && r.now().Sub(cur.loadedAt) < r.ttl {
		return cur
	}
	if r.q == nil {
		return cur
	}

	r.loading.Lock()
	defer r.loading.Unlock()

	// Re-check: another goroutine may have refreshed while we waited.
	r.mu.RLock()
	cur = r.cur
	r.mu.RUnlock()
	if cur != nil && r.now().Sub(cur.loadedAt) < r.ttl {
		return cur
	}

	fresh, err := r.load(ctx)
	if err != nil {
		slog.ErrorContext(ctx, "appconfig.refresh_failed",
			"error", err, "serving_stale", cur != nil)
		return cur
	}

	r.mu.Lock()
	r.cur = fresh
	r.mu.Unlock()
	return fresh
}

func (r *Reader) load(ctx context.Context) (*entry, error) {
	rows, err := r.q.Query(ctx, selectAll)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	e := &entry{
		global:   map[string]string{},
		byOrg:    map[uuid.UUID]map[string]string{},
		loadedAt: r.now(),
	}
	for rows.Next() {
		var key, value string
		var orgID *uuid.UUID
		if err := rows.Scan(&key, &value, &orgID); err != nil {
			return nil, err
		}
		if orgID == nil {
			e.global[key] = value
			continue
		}
		m := e.byOrg[*orgID]
		if m == nil {
			m = map[string]string{}
			e.byOrg[*orgID] = m
		}
		m[key] = value
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}
	return e, nil
}

// Refresh forces a reload, ignoring the TTL. Used by the kill-switch
// runbook to confirm propagation without waiting, and by tests.
func (r *Reader) Refresh(ctx context.Context) error {
	if r.q == nil {
		return nil
	}
	r.loading.Lock()
	defer r.loading.Unlock()
	fresh, err := r.load(ctx)
	if err != nil {
		return err
	}
	r.mu.Lock()
	r.cur = fresh
	r.mu.Unlock()
	return nil
}

// Get resolves key for org: the organization override if present, then
// the global row, then the compiled-in default.
//
// Pass uuid.Nil for org to skip the override lookup.
func (r *Reader) Get(ctx context.Context, key string, org uuid.UUID) string {
	snap := r.snapshot(ctx)
	if snap != nil {
		if org != uuid.Nil {
			if m, ok := snap.byOrg[org]; ok {
				if v, ok := m[key]; ok {
					return v
				}
			}
		}
		if v, ok := snap.global[key]; ok {
			return v
		}
	}
	if v, ok := defaults[key]; ok {
		return v
	}
	slog.WarnContext(ctx, "appconfig.undeclared_key", "key", key)
	return ""
}

// Bool reads key as a boolean. Anything that is not a recognised true or
// false literal resolves to the key's compiled-in default and is logged.
func (r *Reader) Bool(ctx context.Context, key string, org uuid.UUID) bool {
	raw := r.Get(ctx, key, org)
	v, err := strconv.ParseBool(strings.TrimSpace(raw))
	if err != nil {
		slog.WarnContext(ctx, "appconfig.unparseable_value",
			"key", key, "kind", "bool", "falling_back_to_default", true)
		v, _ = strconv.ParseBool(defaults[key])
	}
	return v
}

// Int64 reads key as an integer, falling back to the default on garbage.
func (r *Reader) Int64(ctx context.Context, key string, org uuid.UUID) int64 {
	raw := r.Get(ctx, key, org)
	v, err := strconv.ParseInt(strings.TrimSpace(raw), 10, 64)
	if err != nil {
		slog.WarnContext(ctx, "appconfig.unparseable_value",
			"key", key, "kind", "int64", "falling_back_to_default", true)
		v, _ = strconv.ParseInt(defaults[key], 10, 64)
	}
	return v
}

// Float64 reads key as a float, falling back to the default on garbage.
func (r *Reader) Float64(ctx context.Context, key string, org uuid.UUID) float64 {
	raw := r.Get(ctx, key, org)
	v, err := strconv.ParseFloat(strings.TrimSpace(raw), 64)
	if err != nil {
		slog.WarnContext(ctx, "appconfig.unparseable_value",
			"key", key, "kind", "float64", "falling_back_to_default", true)
		v, _ = strconv.ParseFloat(defaults[key], 64)
	}
	return v
}

// ChatEnabled and ChatMode are the two hot-path reads, named so the call
// sites read as intent rather than as string lookups.
func (r *Reader) ChatEnabled(ctx context.Context, org uuid.UUID) bool {
	return r.Bool(ctx, KeyAIChatEnabled, org)
}

// ChatMode returns ModeFull or ModeDefinedOps. An unrecognised mode
// resolves to ModeDefinedOps: an operator typo must restrict the system,
// never widen it.
func (r *Reader) ChatMode(ctx context.Context, org uuid.UUID) string {
	switch v := strings.TrimSpace(r.Get(ctx, KeyAIChatMode, org)); v {
	case ModeFull, ModeDefinedOps:
		return v
	default:
		slog.WarnContext(ctx, "appconfig.unknown_chat_mode", "restricting_to", ModeDefinedOps)
		return ModeDefinedOps
	}
}

// Default exposes the compiled-in fallback for a key. Used by the admin
// UI to show what the system would do if the row were deleted.
func Default(key string) (string, bool) {
	v, ok := defaults[key]
	return v, ok
}
