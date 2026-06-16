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

-- name: GetPlanByStripePriceID :one
-- Lookup planu po stripe_price_id — używane przy checkout.session.completed
-- żeby wiedzieć ile tokenów przypisać i jaki tier.
SELECT id, tier, cycle, tokens_per_period, licenses_limit, has_b2b_dashboard,
       price_gross, currency_code
FROM subscription_plans
WHERE stripe_price_id = $1
  AND is_active = TRUE
LIMIT 1;

-- name: UpsertStripeSubscription :one
-- Tworzy lub aktualizuje subskrypcję po zdarzeniu Stripe.
-- ON CONFLICT (provider, provider_subscription_id) aktualizuje pola.
-- Używane przy checkout.session.completed i customer.subscription.created.
INSERT INTO subscriptions (
    organization_id, plan_id,
    provider, provider_subscription_id,
    status,
    current_period_start, current_period_end,
    cancel_at_period_end, trial_end_at,
    canceled_at
) VALUES (
    $1, $2,
    'STRIPE', $3,
    $4,
    $5, $6,
    $7, $8,
    $9
)
ON CONFLICT (provider, provider_subscription_id) DO UPDATE
    SET plan_id              = EXCLUDED.plan_id,
        status               = EXCLUDED.status,
        current_period_start = EXCLUDED.current_period_start,
        current_period_end   = EXCLUDED.current_period_end,
        cancel_at_period_end = EXCLUDED.cancel_at_period_end,
        trial_end_at         = EXCLUDED.trial_end_at,
        canceled_at          = EXCLUDED.canceled_at,
        updated_at           = now()
RETURNING id, organization_id, plan_id, provider, provider_subscription_id,
          status, current_period_start, current_period_end,
          cancel_at_period_end, canceled_at, trial_end_at, created_at, updated_at;

-- name: GetSubscriptionByStripeID :one
-- Lookup subskrypcji po stripe subscription ID.
SELECT s.id, s.organization_id, s.plan_id, s.provider,
       s.provider_subscription_id, s.status,
       s.current_period_start, s.current_period_end,
       s.cancel_at_period_end, s.canceled_at, s.trial_end_at,
       s.created_at, s.updated_at,
       p.tokens_per_period AS plan_tokens_per_period,
       p.tier AS plan_tier, p.cycle AS plan_cycle
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
WHERE s.provider = 'STRIPE'
  AND s.provider_subscription_id = $1
LIMIT 1;

-- name: UpdateSubscriptionStatusByStripeID :exec
-- Aktualizuje status subskrypcji i opcjonalnie cancel_at_period_end.
-- Używane przy invoice.payment_failed, customer.subscription.deleted,
-- customer.subscription.updated.
UPDATE subscriptions
SET status               = $2,
    cancel_at_period_end = $3,
    canceled_at          = $4,
    updated_at           = now()
WHERE provider = 'STRIPE'
  AND provider_subscription_id = $1;

-- name: DeactivateOtherActiveSubscriptions :exec
-- Anuluje wszystkie inne aktywne/trialing/past_due subskrypcje dla danej organizacji,
-- oprócz tej o podanym Stripe ID (jeśli podane). Zapobiega to naruszeniu unique index
-- idx_subscriptions_one_active_per_org przy przejściu na płatną subskrypcję.
UPDATE subscriptions
SET status = 'CANCELED',
    canceled_at = now(),
    updated_at = now()
WHERE organization_id = $1
  AND status IN ('ACTIVE', 'TRIALING', 'PAST_DUE')
  AND (provider_subscription_id IS NULL OR provider_subscription_id <> $2);
