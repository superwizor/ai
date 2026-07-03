-- name: GetReservationBySession :one
-- Idempotency lookup PRZED próbą INSERT-u. Zwraca aktywną lub już sfinalizowaną
-- rezerwację (status determinuje co handler robi).
SELECT id, session_id, subscription_id, organization_id,
       tokens_reserved, status, created_at, expires_at, finalized_at, therapist_id
FROM pending_reservations
WHERE session_id = $1;

-- name: CreateReservation :one
-- Tworzy rezerwację. UNIQUE constraint na session_id zapewnia że nawet
-- równoczesny ReserveCredit z różnymi idempotency_keys da tylko jedną
-- rezerwację — drugi dostanie unique-violation i handler przechwyci.
INSERT INTO pending_reservations (
    session_id, subscription_id, organization_id, therapist_id,
    tokens_reserved, expires_at
) VALUES (
    $1, $2, $3, $4, $5, $6
)
RETURNING id, session_id, subscription_id, organization_id,
          tokens_reserved, status, created_at, expires_at, finalized_at, therapist_id;

-- name: MarkReservationCommitted :exec
-- Wywoływane wewnątrz transakcji CommitUsage, po insert do usage_events.
UPDATE pending_reservations
SET status = 'COMMITTED', finalized_at = now()
WHERE session_id = $1 AND status = 'ACTIVE';

-- name: MarkReservationReleased :exec
-- Wywoływane przez ReleaseCredit (jawne anulowanie sesji).
UPDATE pending_reservations
SET status = 'RELEASED', finalized_at = now()
WHERE session_id = $1 AND status = 'ACTIVE';

-- name: MarkExpiredReservations :many
-- Cron job (release-expired-reservations) — zwraca subscription_id +
-- tokens_reserved per row, żeby handler mógł zaktualizować odpowiednie
-- usage_counters w tej samej transakcji.
UPDATE pending_reservations
SET status = 'EXPIRED', finalized_at = now()
WHERE status = 'ACTIVE' AND expires_at < now()
RETURNING id, session_id, subscription_id, therapist_id, tokens_reserved;
