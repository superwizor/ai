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
    cancel_at_period_end, trial_end_at
) VALUES (
    $1, $2,
    'STRIPE', $3,
    $4,
    $5, $6,
    $7, $8
)
ON CONFLICT (provider, provider_subscription_id) DO UPDATE
    SET plan_id              = EXCLUDED.plan_id,
        status               = EXCLUDED.status,
        current_period_start = EXCLUDED.current_period_start,
        current_period_end   = EXCLUDED.current_period_end,
        cancel_at_period_end = EXCLUDED.cancel_at_period_end,
        trial_end_at         = EXCLUDED.trial_end_at,
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
