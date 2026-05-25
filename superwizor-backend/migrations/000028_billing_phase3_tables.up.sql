-- Phase 3 billing schema — token-bucket model per organization (ADR-DM-017).
--
-- Reference: docs/16_BILLING_SERVICE_PHASE_3.md §3.
--
-- Notes:
--   * organizations.id, users.id muszą istnieć przed tą migracją (są od 000003).
--   * provider_customer_id jest szyfrowane envelope (ADR-BL-004) — para
--     ciphertext/encrypted_dek. NULL dopuszczone (np. dla MANUAL provider).
--   * Indeks `idx_subscriptions_one_active_per_org` wymusza biznesowo:
--     jedna aktywna subskrypcja per organizacja w danym momencie.
--   * `usage_events.session_id UNIQUE` to twarda gwarancja idempotencji
--     (ADR-DM-018). Wraz z `pending_reservations.session_id UNIQUE`
--     gwarantuje, że nawet retry z różnymi idempotency_keys nie spali
--     dwóch tokenów na tej samej sesji.
--   * Snapshot semantics dla tokens_limit w usage_counters: mid-cycle
--     upgrade UPDATE-uje wartość; nowy okres tworzy nowy row (§9.3).

-- ============================================================
-- SUBSCRIPTION PLANS (katalog)
-- ============================================================
CREATE TABLE subscription_plans (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tier                     plan_tier NOT NULL,
    cycle                    billing_cycle NOT NULL,
    display_name             VARCHAR(100) NOT NULL,
    price_gross              NUMERIC(10,2) NOT NULL,
    currency_code            CHAR(3) NOT NULL DEFAULT 'PLN',

    tokens_per_period        INT NOT NULL,
    licenses_limit           INT NOT NULL DEFAULT 1,

    has_b2b_dashboard        BOOLEAN NOT NULL DEFAULT FALSE,
    marketing_description    TEXT,

    stripe_price_id          VARCHAR(100),
    p24_plan_id              VARCHAR(100),
    apple_product_id         VARCHAR(100),
    google_product_id        VARCHAR(100),

    is_active                BOOLEAN NOT NULL DEFAULT TRUE,
    created_at               TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_plans_currency CHECK (currency_code ~ '^[A-Z]{3}$'),
    CONSTRAINT chk_plans_price    CHECK (price_gross >= 0),
    CONSTRAINT chk_plans_tokens   CHECK (tokens_per_period >= 0)
);

CREATE UNIQUE INDEX idx_plans_tier_cycle_active
    ON subscription_plans(tier, cycle) WHERE is_active = TRUE;

-- ============================================================
-- SUBSCRIPTIONS
-- ============================================================
CREATE TABLE subscriptions (
    id                                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id                     UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    plan_id                             UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,

    provider                            payment_provider NOT NULL,
    provider_subscription_id            VARCHAR(255) NOT NULL,

    -- ADR-BL-004: envelope encryption
    provider_customer_id_ciphertext     BYTEA,
    provider_customer_id_encrypted_dek  BYTEA,

    status                              subscription_status NOT NULL,
    current_period_start                TIMESTAMPTZ NOT NULL,
    current_period_end                  TIMESTAMPTZ NOT NULL,
    cancel_at_period_end                BOOLEAN NOT NULL DEFAULT FALSE,
    canceled_at                         TIMESTAMPTZ,
    trial_end_at                        TIMESTAMPTZ,

    created_at                          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                          TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (provider, provider_subscription_id),

    CONSTRAINT chk_subscriptions_period CHECK (current_period_end > current_period_start),
    CONSTRAINT chk_subscriptions_encryption_pair CHECK (
        (provider_customer_id_ciphertext IS NULL AND provider_customer_id_encrypted_dek IS NULL)
        OR (provider_customer_id_ciphertext IS NOT NULL AND provider_customer_id_encrypted_dek IS NOT NULL)
    )
);

CREATE UNIQUE INDEX idx_subscriptions_one_active_per_org
    ON subscriptions(organization_id)
    WHERE status IN ('ACTIVE', 'TRIALING', 'PAST_DUE');

CREATE INDEX idx_subscriptions_period_end
    ON subscriptions(current_period_end)
    WHERE status IN ('ACTIVE', 'TRIALING');

-- ============================================================
-- USAGE COUNTERS (per period bucket)
-- ============================================================
CREATE TABLE usage_counters (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id     UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    period_start        TIMESTAMPTZ NOT NULL,
    period_end          TIMESTAMPTZ NOT NULL,

    tokens_used         INT NOT NULL DEFAULT 0,
    tokens_reserved     INT NOT NULL DEFAULT 0,
    tokens_limit        INT NOT NULL,

    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (subscription_id, period_start),
    CONSTRAINT chk_counters_nonneg CHECK (tokens_used >= 0 AND tokens_reserved >= 0),
    CONSTRAINT chk_counters_period CHECK (period_end > period_start)
);

CREATE INDEX idx_usage_counters_active
    ON usage_counters(subscription_id, period_start, period_end);

-- ============================================================
-- PENDING RESERVATIONS (dwufazowy debit, ADR-BL-001)
-- ============================================================
CREATE TABLE pending_reservations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL UNIQUE,
    subscription_id     UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,

    tokens_reserved     INT NOT NULL,
    status              reservation_status NOT NULL DEFAULT 'ACTIVE',

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at          TIMESTAMPTZ NOT NULL,
    finalized_at        TIMESTAMPTZ,

    CONSTRAINT chk_reservations_tokens CHECK (tokens_reserved > 0),
    CONSTRAINT chk_reservations_finalized CHECK (
        (status = 'ACTIVE' AND finalized_at IS NULL)
        OR (status <> 'ACTIVE' AND finalized_at IS NOT NULL)
    )
);

CREATE INDEX idx_pending_reservations_expiry
    ON pending_reservations(expires_at)
    WHERE status = 'ACTIVE';

CREATE INDEX idx_pending_reservations_sub
    ON pending_reservations(subscription_id, status);

-- ============================================================
-- USAGE EVENTS (idempotent commit log, ADR-DM-018)
-- ============================================================
CREATE TABLE usage_events (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL UNIQUE,
    subscription_id     UUID NOT NULL REFERENCES subscriptions(id) ON DELETE RESTRICT,
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,

    tokens_consumed     INT NOT NULL,
    duration_seconds    INT NOT NULL,
    usage_type          VARCHAR(50) NOT NULL DEFAULT 'session_analysis',

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_usage_events_tokens   CHECK (tokens_consumed > 0),
    CONSTRAINT chk_usage_events_duration CHECK (duration_seconds >= 0)
);

CREATE INDEX idx_usage_events_sub_time
    ON usage_events(subscription_id, created_at DESC);

CREATE INDEX idx_usage_events_org_time
    ON usage_events(organization_id, created_at DESC);

-- ============================================================
-- PAYMENT EVENTS (Stripe/P24 raw stream, ADR-BL-002)
--
-- subscription_id NULLABLE — checkout.session.completed może przyjść
-- ZANIM utworzymy subscriptions row (race nasz vs Stripe).
--
-- raw_payload JSONB to single source of truth dla zewnętrznego
-- invoicing SaaS (Fakturownia/iFirma per ADR-DM-016) — nie pakujemy
-- tu zmiennych z payload do osobnych kolumn ponad to co potrzeba dla
-- queryability w naszym kodzie.
-- ============================================================
CREATE TABLE payment_events (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id     UUID REFERENCES subscriptions(id) ON DELETE RESTRICT,

    provider            payment_provider NOT NULL,
    provider_event_id   VARCHAR(255) NOT NULL,
    event_type          VARCHAR(100) NOT NULL,

    amount_gross        NUMERIC(10,2),
    amount_net          NUMERIC(10,2),
    vat_rate            NUMERIC(5,4),
    currency_code       CHAR(3),

    raw_payload         JSONB NOT NULL,
    processing_status   VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    processed_at        TIMESTAMPTZ,
    error_message       TEXT,

    received_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (provider, provider_event_id),
    CONSTRAINT chk_payment_events_status CHECK (
        processing_status IN ('PENDING', 'PROCESSED', 'FAILED', 'IGNORED')
    )
);

CREATE INDEX idx_payment_events_subscription
    ON payment_events(subscription_id, received_at DESC);

CREATE INDEX idx_payment_events_type
    ON payment_events(event_type, received_at DESC);

CREATE INDEX idx_payment_events_unprocessed
    ON payment_events(received_at) WHERE processing_status = 'PENDING';
