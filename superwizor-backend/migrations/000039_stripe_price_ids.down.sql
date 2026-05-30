-- Rollback: usuwa stripe_price_id ze wszystkich planów.
UPDATE subscription_plans SET stripe_price_id = NULL
WHERE tier IN ('SOLO'::plan_tier, 'PRO'::plan_tier);
