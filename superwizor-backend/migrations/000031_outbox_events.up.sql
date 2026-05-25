-- Outbox pattern (ADR-DM-009) — cross-cutting infra dla transactional
-- consistency między DB writem a Pub/Sub publishem.
--
-- Reference: docs/16_BILLING_SERVICE_PHASE_3.md §3.8, docs/02_*.md ADR-DM-009.
--
-- Flow:
--   1. Handler w transakcji modyfikuje stan (np. usage_counters)
--      i robi INSERT do outbox_events.
--   2. Po commicie DB, separate poller (in-process goroutine albo
--      Cloud Function) fetch-uje processed=false, publikuje do Pub/Sub,
--      ustawia processed=true.
--   3. Pub/Sub jest at-least-once, więc consumer (notification-svc, etc.)
--      MUSI być idempotent. Idempotency key = (aggregate_type, event_type,
--      aggregate_id, created_at) ⇒ consumer deduplikuje.
--
-- Notatka: tabela jest shared między serwisami (każdy może pisać outbox).
-- W praktyce w slice 3 tylko billing-svc używa; w przyszłości clinical-svc
-- może przejść z direct publishu na outbox dla session.deleted.

CREATE TABLE outbox_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    -- Aggregate identification — np. ('subscription', 'subscription.created', subscription_id).
    aggregate_type  VARCHAR(50) NOT NULL,
    event_type      VARCHAR(100) NOT NULL,
    aggregate_id    UUID NOT NULL,

    -- Routing — który org/topic dotyczy event (consumer może filtrować).
    organization_id UUID NOT NULL,

    -- Pełen payload — JSONB żeby consumer mógł go odczytać bez znajomości
    -- schematu w czasie kompilacji (loose coupling).
    payload         JSONB NOT NULL,

    -- Poller state machine.
    processed       BOOLEAN NOT NULL DEFAULT FALSE,
    published_at    TIMESTAMPTZ,
    attempts        INT NOT NULL DEFAULT 0,
    last_error      TEXT,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_outbox_processed_consistency CHECK (
        (processed = FALSE AND published_at IS NULL)
        OR (processed = TRUE AND published_at IS NOT NULL)
    )
);

-- Poller — fetch oldest unprocessed pierwszych. Częściowy indeks żeby nie
-- bloater-ować całej tabeli (po publish row staje się "balastem" dla zapytań
-- pollera, ale zostaje do retention purge).
CREATE INDEX idx_outbox_unpublished
    ON outbox_events(created_at)
    WHERE processed = FALSE;

-- Lookup po aggregate dla retry/replay (np. "pokaż mi wszystkie eventy
-- dla tej subskrypcji w ostatnich 24h").
CREATE INDEX idx_outbox_aggregate
    ON outbox_events(aggregate_type, aggregate_id, created_at DESC);
