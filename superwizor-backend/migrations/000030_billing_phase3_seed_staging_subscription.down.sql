-- Rollback usuwa subskrypcje MANUAL ze sufiksem 'manual-staging-' wraz z
-- ich usage_counters (ON DELETE CASCADE). Bezpieczne — `manual-staging-`
-- prefix nigdy nie pojawi się w realnym ruchu Stripe/P24.
DELETE FROM subscriptions
WHERE provider = 'MANUAL'
  AND provider_subscription_id LIKE 'manual-staging-%';
