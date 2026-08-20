-- 000086: chat_usage_counters — per-therapist AI chat budget.
--
-- Spec: docs/63 F6; ADR docs/kronikarz/62 section 10. Decision D3:
-- $1.50/month default, period = the subscription month, revisit after 30
-- days of real data.
--
-- ══ Integer money ══
--
-- Everything is micro-USD (1e-6 USD) as BIGINT. NUMERIC would be exact
-- too, but the reservation protocol below runs a conditional UPDATE on
-- every turn and integer comparison is both faster and impossible to
-- misread. Floats were never a candidate: a budget accumulated in
-- float8 over hundreds of thousands of turns drifts, and it drifts in
-- whichever direction nobody is checking.
--
-- ══ Reserve / commit / release ══
--
-- A turn reserves an upper-bound estimate BEFORE the first model call —
-- before the classifier — then commits the real cost from the provider's
-- UsageMetadata and releases the remainder. Reserving first is what makes
-- an exhausted budget cost zero model calls to refuse, and what stops two
-- concurrent turns from both passing a check-then-spend race.
--
-- micro_usd_reserved therefore holds in-flight money. It is NOT spend:
-- a crashed process leaves a reservation behind, which is what
-- reserved_stale_after exists to reclaim.
--
-- ══ FK cascade rationale (ADR-DM-010) ══
--
--   - therapist_id -> users.id ON DELETE CASCADE: a budget for a deleted
--     user is unreachable, and the row carries no clinical content.

CREATE TABLE chat_usage_counters (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    therapist_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Billing period. Half-open [period_start, period_end): a turn at
    -- exactly period_end belongs to the next period, so a turn can never
    -- land in two periods or in none.
    period_start        TIMESTAMPTZ NOT NULL,
    period_end          TIMESTAMPTZ NOT NULL,

    -- Committed spend for the period.
    micro_usd_used      BIGINT NOT NULL DEFAULT 0,

    -- In-flight reservations. Always >= 0; enforced below because a
    -- negative reservation would silently hand out free budget.
    micro_usd_reserved  BIGINT NOT NULL DEFAULT 0,

    -- Effective limit, copied from app_config at period creation so a
    -- mid-period change to the global default cannot retroactively
    -- overspend or under-spend a period already in progress.
    micro_usd_limit     BIGINT NOT NULL,

    -- Set when the 80% warning was delivered, so it is shown once rather
    -- than on every turn after the threshold.
    warned_at           TIMESTAMPTZ,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chat_usage_counters_nonneg
        CHECK (micro_usd_used >= 0 AND micro_usd_reserved >= 0 AND micro_usd_limit >= 0),
    CONSTRAINT chat_usage_counters_period
        CHECK (period_end > period_start),

    -- One counter per therapist per period. This is what makes the
    -- reservation UPDATE below a single-row atomic operation.
    UNIQUE (therapist_id, period_start)
);

-- The hot path: find this therapist's current period.
CREATE INDEX idx_chat_usage_current
    ON chat_usage_counters(therapist_id, period_end DESC);

COMMENT ON TABLE chat_usage_counters IS
    'Per-therapist AI chat budget in micro-USD. Reserve-before-classifier, '
    'commit-by-UsageMetadata. See docs/63 F6 and ADR 62 section 10.';

COMMENT ON COLUMN chat_usage_counters.micro_usd_reserved IS
    'In-flight reservations, NOT spend. A crashed turn leaves one behind; '
    'the reclaim path in internal/chat/quota.go sweeps stale reservations.';

COMMENT ON COLUMN chat_usage_counters.micro_usd_limit IS
    'Copied from app_config at period creation. Deliberately not read live: '
    'a mid-period change to the global default must not rewrite a period '
    'already in progress.';

-- ── Stale reservation reclaim ────────────────────────────────────────
--
-- A process that dies between reserve and commit leaks its reservation.
-- Rather than a background job, each reservation records when it was
-- taken; the sweep runs opportunistically on the next reserve for the
-- same therapist. That keeps the mechanism in one place and means a
-- therapist who never returns cannot be blocked by their own ghost.

CREATE TABLE chat_usage_reservations (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    counter_id     UUID NOT NULL REFERENCES chat_usage_counters(id) ON DELETE CASCADE,
    micro_usd      BIGINT NOT NULL CHECK (micro_usd >= 0),
    created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_chat_usage_reservations_counter
    ON chat_usage_reservations(counter_id, created_at);

COMMENT ON TABLE chat_usage_reservations IS
    'Open reservations, one row per in-flight turn. Deleted on commit or '
    'release; swept when older than the stale window (see quota.go).';
