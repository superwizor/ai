-- name: AppendOutboxEvent :one
-- Wstawiany wewnątrz transakcji razem z mutacją stanu (np. CommitTokens),
-- żeby Pub/Sub publish był transactionally spójny z DB writem (ADR-DM-009).
INSERT INTO outbox_events (
    aggregate_type, event_type, aggregate_id,
    organization_id, payload
) VALUES (
    $1, $2, $3, $4, $5
)
RETURNING id, aggregate_type, event_type, aggregate_id,
          organization_id, payload, processed, published_at,
          attempts, last_error, created_at;

-- name: FetchUnpublishedOutboxBatch :many
-- Poller: pobiera oldest unprocessed events. FOR UPDATE SKIP LOCKED pozwala
-- multiple poller instances pracować równolegle bez double-publishu
-- (każda instancja bierze "swój" subset).
--
-- LIMIT zarządzany z aplikacji żeby kontrolować batch size.
SELECT id, aggregate_type, event_type, aggregate_id,
       organization_id, payload, attempts, created_at
FROM outbox_events
WHERE processed = FALSE
  AND attempts < 10
ORDER BY created_at ASC
LIMIT $1
FOR UPDATE SKIP LOCKED;

-- name: MarkOutboxEventPublished :exec
-- Wywoływane PO udanym publish do Pub/Sub.
UPDATE outbox_events
SET processed = TRUE,
    published_at = now()
WHERE id = $1;

-- name: MarkOutboxEventFailed :exec
-- Wywoływane PO failed publish. Inkrementuje attempts; po 10 próbach
-- (chk constraint FetchUnpublished) event nie będzie więcej fetchowany —
-- DLQ-equivalent.
UPDATE outbox_events
SET attempts = attempts + 1,
    last_error = $2
WHERE id = $1;
