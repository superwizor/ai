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
