-- email_drip_log — tracks which lifecycle emails were sent to which users,
-- ensuring idempotency (no double-sends) for the cron-driven drip campaign.
--
-- The UNIQUE constraint on (user_id, template_name, subscription_id) means
-- each template is sent at most once per subscription per user.

CREATE TABLE email_drip_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    template_name TEXT NOT NULL,
    subscription_id UUID NOT NULL REFERENCES subscriptions(id),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_email_drip UNIQUE (user_id, template_name, subscription_id)
);

CREATE INDEX idx_email_drip_template ON email_drip_log (template_name, sent_at);
CREATE INDEX idx_email_drip_user ON email_drip_log (user_id);
