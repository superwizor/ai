-- name: GetActiveSubscriptionByOrg :one
-- Zwraca pojedynczą subskrypcję uznawaną za "billing-relevant".
-- Constraint idx_subscriptions_one_active_per_org gwarantuje, że
-- jest co najwyżej jedna w stanie ACTIVE/TRIALING/PAST_DUE.
-- Zwracamy też plan-side dane potrzebne do QuotaDecision bez dodatkowego query.
SELECT
    s.id, s.organization_id, s.plan_id, s.provider,
    s.provider_subscription_id, s.status,
    s.current_period_start, s.current_period_end,
    s.cancel_at_period_end, s.canceled_at, s.trial_end_at,
    s.created_at, s.updated_at,
    p.tier AS plan_tier,
    p.tokens_per_period AS plan_tokens_per_period,
    p.licenses_limit AS plan_licenses_limit
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
WHERE s.organization_id = $1
  AND s.status IN ('ACTIVE', 'TRIALING', 'PAST_DUE')
LIMIT 1;

-- name: GetSubscriptionByID :one
SELECT * FROM subscriptions WHERE id = $1;
