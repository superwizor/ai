-- name: CreatePaymentEvent :one
-- Idempotent insert zdarzenia płatności (ADR-BL-002).
-- UNIQUE(provider, provider_event_id) zapewnia że to samo zdarzenie
-- Stripe nie zostanie przetworzone dwukrotnie — zwraca pusty RETURNING
-- przy konflikcie (caller sprawdza czy id jest zero UUID).
INSERT INTO payment_events (
    provider, provider_event_id, event_type,
    amount_gross, amount_net, vat_rate, currency_code,
    raw_payload, processing_status,
    received_at
) VALUES (
    $1, $2, $3,
    $4, $5, $6, $7,
    $8, $9,
    now()
)
ON CONFLICT (provider, provider_event_id) DO NOTHING
RETURNING id, provider, provider_event_id, event_type, processing_status, received_at;

-- name: CreatePaymentEventStub :one
-- Insert webhook event jako IGNORED (stub mode). UNIQUE constraint na
-- (provider, provider_event_id) zwróci unique-violation przy duplikacie —
-- caller (StripeStubHandler) używa tego do idempotency check.
INSERT INTO payment_events (
    provider, provider_event_id, event_type,
    raw_payload, processing_status, error_message,
    received_at
) VALUES (
    $1, $2, $3, $4, 'IGNORED', $5, now()
)
RETURNING id, provider, provider_event_id, event_type, processing_status, received_at;

-- name: MarkPaymentEventProcessed :exec
UPDATE payment_events
SET processing_status = 'PROCESSED',
    processed_at      = now()
WHERE id = $1;

-- name: MarkPaymentEventFailed :exec
UPDATE payment_events
SET processing_status = 'FAILED',
    error_message     = $2,
    processed_at      = now()
WHERE id = $1;
