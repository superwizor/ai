-- 000015: report customization — per-therapist style preferences +
-- 👍/👎 rating feedback + suggestion-engine telemetry.
--
-- Spec: docs/10_REPORT_CUSTOMIZATION.md
-- Feature flag rollout: not gated; defaults make the feature a no-op
-- for users who never visit the preferences screen.
--
-- Three changes:
--   1. ALTER users ADD COLUMN report_preferences JSONB
--      — empty object means "use all defaults"; preserves existing
--      report generation byte-for-byte until a user customizes.
--   2. CREATE TABLE report_ratings
--      — one row per (report, therapist) pair via UNIQUE constraint
--      so a user re-rating upserts in place rather than accumulating.
--   3. CREATE TABLE preference_suggestions_log
--      — telemetry for the suggestion engine; not user-facing state.
--      Safe to TRUNCATE without product impact (loses history only).
--
-- FK cascade rationale (per ADR-DM-010, explicit cascades require
-- justification — same pattern as migration 000012/000014):
--   - report_ratings.report_id → reports.id ON DELETE CASCADE:
--     a rating on a deleted report has no meaning; preserving it
--     creates orphans the analytics queries have to filter out.
--   - report_ratings.therapist_id → users.id ON DELETE CASCADE:
--     GDPR erasure path — when a user row goes away, their ratings
--     (which carry no shared/clinical content, just style feedback)
--     go with them.
--   - preference_suggestions_log.therapist_id → users.id ON DELETE
--     CASCADE: same GDPR rationale; telemetry rows are derivative.

-- 1. PREFERENCES on users
ALTER TABLE users
    ADD COLUMN report_preferences JSONB NOT NULL DEFAULT '{}'::jsonb;

COMMENT ON COLUMN users.report_preferences IS
    'Per-therapist style preferences for llm-worker call 2 report '
    'generation. Empty object {} = all defaults (current behavior). '
    'Shape documented in docs/10_REPORT_CUSTOMIZATION.md §7.';

-- 2. REPORT_RATINGS — 👍/👎 feedback per report per therapist
CREATE TABLE report_ratings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id       UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    therapist_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Binary rating; chips below give detail on the negative path.
    rating          TEXT NOT NULL CHECK (rating IN ('positive','negative')),

    -- Chip categories selected on the negative-rating modal. TEXT[]
    -- (not JSONB) so the suggestion engine can GROUP BY trivially.
    -- Allowed values policed in app layer; not enforced by CHECK
    -- because the chip set may evolve faster than migrations.
    issues          TEXT[] NOT NULL DEFAULT '{}',

    -- Optional free-form note (≤200 chars). Sanitized server-side
    -- (newlines stripped, prompt-injection patterns rejected) same
    -- as users.report_preferences.free_text.
    notes           TEXT NOT NULL DEFAULT '',

    -- Provenance: where the rating came from. "in_app" for the
    -- bottom-of-report widget today; future: "email", "post_session".
    source          TEXT NOT NULL DEFAULT 'in_app',

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- One rating per (report, therapist). Re-rating UPSERTs.
    UNIQUE (report_id, therapist_id)
);

-- Look-up by therapist, ordered by recency — used by the
-- "your recent ratings" view + the suggestion engine query.
CREATE INDEX idx_report_ratings_therapist
    ON report_ratings(therapist_id, created_at DESC);

-- Partial index for the suggestion engine: only negatives matter
-- when deciding whether to show a propose-config banner.
CREATE INDEX idx_report_ratings_negative
    ON report_ratings(therapist_id, created_at DESC)
    WHERE rating = 'negative';

COMMENT ON TABLE report_ratings IS
    'LLM-chat-style 👍/👎 feedback on therapist_reports. '
    'See docs/10_REPORT_CUSTOMIZATION.md §5.';

-- 3. PREFERENCE_SUGGESTIONS_LOG — telemetry only, not user state.
-- Pure analytics for the v1 suggestion engine: each banner shown,
-- applied, or dismissed gets one row. Used to tune trigger thresholds.
CREATE TABLE preference_suggestions_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    therapist_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Which preference dimension the suggestion targets:
    -- 'length' | 'tone' | 'quote_density' | 'diagnostic_language'
    -- | 'hypothesis_hedging' | 'section_emphasis' | 'strengths_framing'
    dimension       TEXT NOT NULL,
    from_value      TEXT NOT NULL,
    to_value        TEXT NOT NULL,

    -- How many negative ratings of the relevant chip category drove
    -- this banner (≥3 by current trigger).
    trigger_count   INT NOT NULL,

    -- Lifecycle: 'shown' → either 'applied' or 'dismissed'. Three
    -- separate rows per banner is intentional; lets us measure
    -- conversion rate without window functions.
    action          TEXT NOT NULL CHECK (action IN ('shown','applied','dismissed')),

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_pref_sugg_log_therapist
    ON preference_suggestions_log(therapist_id, created_at DESC);

COMMENT ON TABLE preference_suggestions_log IS
    'Suggestion engine telemetry. Pure analytics; safe to TRUNCATE. '
    'See docs/10_REPORT_CUSTOMIZATION.md §6.';
