-- name: GetActiveSubscriptionByOrg :one
-- Zwraca pojedynczą subskrypcję uznawaną za "billing-relevant".
-- Constraint idx_subscriptions_one_active_per_org gwarantuje, że
-- jest co najwyżej jedna w stanie ACTIVE/TRIALING/PAST_DUE.
-- Zwracamy też plan-side dane potrzebne do QuotaDecision bez dodatkowego query.
--
-- DETERMINISTYCZNY wybór (feat/tokens-exhausted, 2026-05-30): mimo że
-- partial-unique index gwarantuje co najwyżej jeden ACTIVE/TRIALING/
-- PAST_DUE per org, kiedyś inwariant został naruszony (failed
-- TRIAL→paid upgrade zostawił dwa wiersze). Bez ORDER BY `LIMIT 1`
-- zwracał DOWOLNY z nich — w incydencie 2026-05-29 zwracał stary
-- TRIAL (3 tokeny) zamiast nowego Solo (20), powodując fałszywe
-- QUOTA_EXHAUSTED. ORDER BY poniżej preferuje płatny plan:
--   1. ACTIVE > TRIALING > PAST_DUE  (płatny aktywny wygrywa z trialem)
--   2. najnowszy created_at          (upgrade jest nowszy niż trial)
-- Dzięki temu reserve/quota zawsze patrzy na plan, za który klient
-- faktycznie płaci, nawet jeśli inwariant zostanie kiedyś naruszony.
SELECT
    s.id, s.organization_id, s.plan_id, s.provider,
    s.provider_subscription_id, s.status,
    s.current_period_start, s.current_period_end,
    s.cancel_at_period_end, s.canceled_at, s.trial_end_at,
    s.created_at, s.updated_at,
    p.tier AS plan_tier,
    p.cycle AS plan_cycle,
    p.tokens_per_period AS plan_tokens_per_period,
    p.licenses_limit AS plan_licenses_limit
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
WHERE s.organization_id = $1
  AND s.status IN ('ACTIVE', 'TRIALING', 'PAST_DUE')
ORDER BY
    CASE s.status
        WHEN 'ACTIVE'   THEN 0
        WHEN 'PAST_DUE' THEN 1
        WHEN 'TRIALING' THEN 2
        ELSE 3
    END,
    s.created_at DESC
LIMIT 1;

-- name: GetSubscriptionByID :one
SELECT * FROM subscriptions WHERE id = $1;
