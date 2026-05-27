-- name: GetUsageEventBySession :one
-- Idempotency lookup. Zwraca już zaistniały event jeśli był (no-op path
-- w CommitUsage).
SELECT id, session_id, subscription_id, organization_id,
       tokens_consumed, duration_seconds, usage_type, created_at
FROM usage_events
WHERE session_id = $1;

-- name: CreateUsageEvent :one
-- Insert idempotent po session_id (UNIQUE constraint). Race: dwóch równoczesnych
-- CommitUsage z tym samym session_id — jeden wygrywa INSERT, drugi dostaje
-- unique-violation. Handler przechwytuje i refetchuje przez GetUsageEventBySession.
--
-- Nie używamy ON CONFLICT DO NOTHING bo chcemy rozróżnić "świeży insert"
-- (zwiększyć counter) od "duplikatu" (no-op).
INSERT INTO usage_events (
    session_id, subscription_id, organization_id,
    tokens_consumed, duration_seconds, usage_type
) VALUES (
    $1, $2, $3, $4, $5, $6
)
RETURNING id, session_id, subscription_id, organization_id,
          tokens_consumed, duration_seconds, usage_type, created_at;
