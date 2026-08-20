-- 000084: app_config — runtime configuration read by the services at
-- request time, with an optional per-organization override.
--
-- Spec: docs/63_AI_CHAT_GUARDRAIL_IMPLEMENTATION_PLAN.md F0/F5.
--
-- Why a table and not environment variables: ADR
-- (docs/kronikarz/62_ADR_AI_Chat_Klasyfikator_Web_Mobile_v1.0_2.md, §11)
-- requires the AI chat kill switch to take effect in under an hour, and
-- targets under five minutes. An env-var change means a Cloud Run deploy
-- and a revision rollout — minutes at best, and it fails exactly when the
-- platform is unhealthy, which is when the switch is needed. A row update
-- propagates within the reader's cache TTL (30 s).
--
-- Values are TEXT, parsed by the reader (pkg/appconfig). JSONB was
-- rejected: every value in the initial set is a scalar, and TEXT keeps the
-- runbook a plain UPDATE that an operator can type from memory under
-- pressure.
--
-- FK cascade rationale (ADR-DM-010 — explicit cascades require
-- justification):
--   - organization_id -> organizations.id ON DELETE CASCADE: an override
--     scoped to a deleted organization can never be read again; keeping
--     it would leave rows that shadow nothing.
--   - updated_by -> users.id ON DELETE SET NULL: the config value must
--     outlive the admin who set it. Losing the attribution is acceptable;
--     losing a kill-switch state because an account was deleted is not.

CREATE TABLE app_config (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    key             TEXT NOT NULL,

    -- Scalar value as text. Interpretation belongs to the reader:
    -- bool ('true'/'false'), int, float, or a free string.
    value           TEXT NOT NULL,

    -- NULL = global default. A non-NULL row overrides the global for
    -- that organization only.
    organization_id UUID REFERENCES organizations(id) ON DELETE CASCADE,

    -- Free-text note explaining why a non-default value is in place.
    -- Read by whoever finds the switch flipped at 3am.
    note            TEXT NOT NULL DEFAULT '',

    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_by      UUID REFERENCES users(id) ON DELETE SET NULL
);

-- One row per (key, scope). Two partial unique indexes rather than one
-- UNIQUE (key, organization_id): in SQL, NULL is distinct from NULL, so a
-- plain composite unique would happily admit two global rows for the same
-- key and the reader would pick one arbitrarily.
CREATE UNIQUE INDEX idx_app_config_global
    ON app_config(key)
    WHERE organization_id IS NULL;

CREATE UNIQUE INDEX idx_app_config_org
    ON app_config(key, organization_id)
    WHERE organization_id IS NOT NULL;

-- The read path: one key, global + this org, resolved in the reader.
CREATE INDEX idx_app_config_lookup
    ON app_config(key, organization_id);

COMMENT ON TABLE app_config IS
    'Runtime configuration with per-organization overrides. Read via '
    'pkg/appconfig (30 s cache). Hosts the AI chat kill switch — see '
    'docs/63 F0/F5 and ADR 62 section 11. NOT covered by the GDPR purger: '
    'contains no personal data.';

COMMENT ON COLUMN app_config.organization_id IS
    'NULL = global default; non-NULL = override for that organization.';

-- ── Seed: AI chat control surface ────────────────────────────────────
--
-- Seeded disabled. The chat backend ships dark and is switched on per
-- environment, so a deploy can never enable a half-wired feature.
INSERT INTO app_config (key, value, note) VALUES
    ('AI_CHAT_ENABLED', 'false',
     'Master kill switch (ADR 62 section 11). false = chat RPCs refuse with FEATURE_DISABLED.'),
    ('AI_CHAT_MODE', 'full',
     'full = all intents; defined_ops = A8-A10 unavailable, degraded to A7/A2.'),
    ('AI_CHAT_CLASSIFIER_TAU', '0.85',
     'Confidence threshold. Below it the router degrades. Calibrated in F8; never lower to reduce false positives on ALLOWED.'),
    ('AI_CHAT_QUOTA_MICRO_USD', '1500000',
     'Default monthly per-therapist chat budget in micro-USD. 1500000 = $1.50 (decision D3, revisit after 30 days of data).');
