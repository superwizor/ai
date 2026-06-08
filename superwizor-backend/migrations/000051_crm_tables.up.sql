-- Migration 000051: CRM tables for Marcin's relationship management.
--
-- crm_notes:          Private admin notes per therapist (journal entries).
-- crm_follow_ups:     Scheduled follow-up reminders.
-- crm_tags:           Free-form tags per therapist for segmentation.
-- crm_excluded_users: Hides users from CRM view (test accounts, spam).
--
-- These are internal admin data — NOT PHI. No encryption needed.

-- ── Notes ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS crm_notes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id   TEXT NOT NULL,
    target_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body            TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_notes_target
    ON crm_notes(target_user_id, created_at DESC);

-- ── Follow-ups ───────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS crm_follow_ups (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id   TEXT NOT NULL,
    target_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    due_date        DATE NOT NULL,
    note            TEXT,
    completed       BOOLEAN NOT NULL DEFAULT false,
    completed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_crm_followup UNIQUE (admin_user_id, target_user_id, due_date)
);

CREATE INDEX IF NOT EXISTS idx_crm_followups_due
    ON crm_follow_ups(due_date) WHERE NOT completed;

-- ── Tags ─────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS crm_tags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    target_user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    tag             TEXT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_crm_tag UNIQUE (target_user_id, tag)
);

CREATE INDEX IF NOT EXISTS idx_crm_tags_user
    ON crm_tags(target_user_id);

-- ── Excluded users ───────────────────────────────────────────

CREATE TABLE IF NOT EXISTS crm_excluded_users (
    user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    excluded_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason          TEXT
);
