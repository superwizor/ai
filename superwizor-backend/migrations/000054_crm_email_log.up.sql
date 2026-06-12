-- Migration 000054: CRM email log for tracking sent emails/reminders.
--
-- Tracks when Marcin opens a templated email via mailto: link,
-- so the CRM can show "last contacted" and prevent spamming.
--
-- Internal admin data — NOT PHI. No encryption needed.

CREATE TABLE IF NOT EXISTS crm_email_log (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_user_id     TEXT NOT NULL,
    target_user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id       TEXT NOT NULL,
    subject           TEXT NOT NULL,
    recipient_email   TEXT NOT NULL,
    sent_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_crm_email_log_target
    ON crm_email_log(target_user_id, sent_at DESC);
