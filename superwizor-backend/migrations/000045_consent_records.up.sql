-- 000045 — consent_records (RODO compliance)
--
-- consent_records table stores the history of user consent choices (TOS, MARKETING, RECORDING, etc.).
-- Under GDPR, consent must be auditable, which means we must track when it was given or revoked,
-- from which IP address, using what User Agent, and the specific version of the agreement.

CREATE TABLE consent_records (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_type    TEXT NOT NULL, -- e.g., 'TOS', 'MARKETING', 'RECORDING'
    granted         BOOLEAN NOT NULL,
    consent_version TEXT,          -- e.g., 'v1.0.2', '2026-06-01'
    ip_address      TEXT,
    user_agent      TEXT,
    recorded_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index to quickly query consent history for a given user.
CREATE INDEX idx_consent_records_user ON consent_records (user_id, recorded_at DESC);
