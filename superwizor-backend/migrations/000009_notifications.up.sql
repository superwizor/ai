-- ============================================
-- FCM TOKENS — per-user device tokens
-- ============================================
-- Multi-token per user (iPhone + iPad + Android scenario, ADR-IMPL-011).
-- Soft delete via invalidated_at — set when FCM returns NotRegistered.

CREATE TABLE fcm_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    token           TEXT NOT NULL,         -- opaque FCM identifier; not PHI (ADR-IMPL-013)
    platform        VARCHAR(20) NOT NULL,  -- 'ios' | 'android' | 'web'
    app_version     VARCHAR(32),
    device_model    VARCHAR(100),
    locale          VARCHAR(10),           -- 'pl-PL' | 'en-US' for FCM body localization

    last_used_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Soft delete on FCM NotRegistered / token rotation. Hard delete via cron > 30 days (Phase 4).
    invalidated_at      TIMESTAMPTZ,
    invalidated_reason  VARCHAR(50)        -- 'fcm_not_registered' | 'user_logout' | 'rotated'
);

-- Active tokens unique by (user, token). Allows historical inactive rows
-- with the same string to coexist (rare but possible after rotation).
CREATE UNIQUE INDEX idx_fcm_tokens_active_user_token
    ON fcm_tokens(user_id, token)
    WHERE invalidated_at IS NULL;

CREATE INDEX idx_fcm_tokens_user_active
    ON fcm_tokens(user_id, last_used_at DESC)
    WHERE invalidated_at IS NULL;

-- ============================================
-- NOTIFICATION DELIVERIES — audit + idempotency
-- ============================================
-- Every attempted FCM send gets a row. The idempotency key prevents
-- duplicate sends from at-least-once Pub/Sub delivery (P1 Zero Data Loss).

CREATE TYPE notification_status AS ENUM (
    'queued',
    'sent',
    'failed',
    'token_invalid'
);

CREATE TABLE notification_deliveries (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id           UUID NOT NULL REFERENCES users(id),
    session_id        UUID REFERENCES sessions(id),

    notification_type VARCHAR(50) NOT NULL,  -- 'report_ready' | 'session_failed' | ...
    fcm_message_id    VARCHAR(255),          -- returned by Firebase Admin SDK on success

    -- Idempotency: typically `${session_id}:${notification_type}`.
    -- Same key → no duplicate send (INSERT ... ON CONFLICT DO NOTHING).
    idempotency_key   VARCHAR(128) NOT NULL UNIQUE,

    target_token_id   UUID REFERENCES fcm_tokens(id) ON DELETE SET NULL,

    status            notification_status NOT NULL DEFAULT 'queued',
    error_code        VARCHAR(100),  -- 'NotRegistered' | 'QuotaExceeded' | etc.
    error_message     TEXT,

    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    sent_at           TIMESTAMPTZ
);

CREATE INDEX idx_notif_deliveries_user_recent
    ON notification_deliveries(user_id, created_at DESC);

CREATE INDEX idx_notif_deliveries_session
    ON notification_deliveries(session_id, created_at DESC)
    WHERE session_id IS NOT NULL;

CREATE INDEX idx_notif_deliveries_status_recent
    ON notification_deliveries(status, created_at DESC)
    WHERE status IN ('queued', 'failed');
