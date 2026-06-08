-- name: ListExpiredManualSubscriptions :many
-- Cron daily o 00:05 UTC — znajduje MANUAL subskrypcje (ACTIVE + TRIALING),
-- których bieżący okres rozliczeniowy się skończył (period_end < now).
-- TRIALING status covers BETA plan subscriptions (120 tokens × 2 months).
-- Per row musimy: shift current_period_*, utworzyć nowy usage_counters.
SELECT
    s.id, s.organization_id, s.plan_id,
    s.current_period_start, s.current_period_end,
    p.tokens_per_period
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
WHERE s.provider = 'MANUAL'
  AND s.status IN ('ACTIVE', 'TRIALING')
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

-- ──────────────────────────────────────────────────────────────────
-- Web-admin RPCs (docs/18 §13.7) — SUPERWIZOR_ADMIN actions.
-- ──────────────────────────────────────────────────────────────────

-- name: AdminGetPlanByTierCycle :one
-- Resolves a (plan_tier, billing_cycle) pair to the live subscription_plans
-- row — used by AdminChangePlan to look up the new tier's tokens_per_period.
SELECT * FROM subscription_plans
WHERE tier  = sqlc.arg(tier)::plan_tier
  AND cycle = sqlc.arg(cycle)::billing_cycle
  AND is_active = TRUE
LIMIT 1;

-- name: AdminUpdateCounter :one
-- AdminResetTokens core. Selective COALESCE — pass NULL on tokens_used or
-- tokens_limit to leave that column unchanged. The handler maps proto
-- value -1 (sentinel) to NULL before calling.
UPDATE usage_counters
SET tokens_used  = COALESCE(sqlc.narg(tokens_used)::int,  tokens_used),
    tokens_limit = COALESCE(sqlc.narg(tokens_limit)::int, tokens_limit),
    updated_at   = now()
WHERE id = sqlc.arg(id)
RETURNING *;

-- name: AdminChangeSubscriptionPlan :one
-- AdminChangePlan step 1. Flips subscriptions.plan_id to the new plan.
-- tokens_used + tokens_reserved on the active counter are LEFT ALONE;
-- only tokens_limit is updated separately (via AdminUpdateCounter using
-- the new plan's tokens_per_period). If the operator wants a clean
-- slate, they follow up with AdminResetTokens.
UPDATE subscriptions
SET plan_id    = $2,
    updated_at = now()
WHERE id = $1
RETURNING *;

-- name: CreateBillingAuditEvent :one
-- Web-admin actions (SUPERWIZOR_ADMIN) on billing data land here. Mirrors
-- identity-svc's audit_events insert. reason is enforced >=10 chars at
-- the handler level, NOT NULL-allowed at the schema level (legacy events
-- don't have it populated).
INSERT INTO audit_events (
    actor_user_id, organization_id, action,
    resource_type, resource_id, metadata, reason
) VALUES (
    sqlc.narg(actor_user_id),
    sqlc.narg(organization_id),
    sqlc.arg(action),
    sqlc.arg(resource_type),
    sqlc.narg(resource_id),
    sqlc.arg(metadata),
    sqlc.narg(reason)
)
RETURNING *;
