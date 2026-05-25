-- name: ListExpiredManualSubscriptions :many
-- Cron daily o 00:05 UTC — znajduje MANUAL ACTIVE subskrypcje, których
-- bieżący okres rozliczeniowy się skończył (period_end < now).
-- Per row musimy: shift current_period_*, utworzyć nowy usage_counters.
SELECT
    s.id, s.organization_id, s.plan_id,
    s.current_period_start, s.current_period_end,
    p.tokens_per_period
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
WHERE s.provider = 'MANUAL'
  AND s.status = 'ACTIVE'
  AND s.current_period_end < now();

-- name: ShiftSubscriptionPeriod :exec
-- Atomic shift okresu rozliczeniowego — używane przez manual renewal cron
-- ORAZ (w slice 2) przez Stripe invoice.paid handler.
UPDATE subscriptions
SET current_period_start = $2,
    current_period_end   = $3,
    updated_at = now()
WHERE id = $1;

-- name: CreateUsageCounter :one
-- Tworzy nowy bucket licznika dla rozpoczętego okresu. UNIQUE (subscription_id,
-- period_start) chroni przed double-create przy concurrent renewal.
INSERT INTO usage_counters (
    subscription_id, period_start, period_end,
    tokens_used, tokens_reserved, tokens_limit
) VALUES (
    $1, $2, $3, 0, 0, $4
)
RETURNING id, subscription_id, period_start, period_end,
          tokens_used, tokens_reserved, tokens_limit, updated_at;

-- name: ListSubscriptionsMissingCounter :many
-- Weekly safety-check — znajdź ACTIVE/TRIALING subskrypcje, które nie mają
-- aktywnego usage_counters dla bieżącego momentu. Jeśli się pojawi
-- którakolwiek — alert (cron triggeruje monitoring).
SELECT s.id, s.organization_id, s.plan_id, s.current_period_start, s.current_period_end,
       p.tokens_per_period
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
WHERE s.status IN ('ACTIVE', 'TRIALING')
  AND NOT EXISTS (
    SELECT 1 FROM usage_counters c
    WHERE c.subscription_id = s.id
      AND c.period_start <= now()
      AND c.period_end > now()
);
