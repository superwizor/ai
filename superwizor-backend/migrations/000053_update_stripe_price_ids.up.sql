-- Update stripe_price_id to match current Stripe Sandbox prices (2026-06-08).
--
-- Migration 000039 seeded price IDs from the initial sandbox setup (2026-05-30,
-- 149 PLN for Solo, older prices). After the pricing decision in migration 000048
-- (SOLO=179 PLN, PRO=299 PLN), new Stripe prices were created but the DB
-- stripe_price_id columns were NOT updated.
--
-- The marketing-site plans.ts already uses the correct (newer) price IDs.
-- Without this fix, the Stripe webhook handler's GetPlanByStripePriceID query
-- returns pgx.ErrNoRows → subscription is silently not provisioned after checkout.
--
-- Price verification via Stripe API (2026-06-12):
--   SOLO MONTHLY price_1TgAk2E5jzWcAIgeQ572wpkE → 179.00 PLN ✓ (prod_UbzUdnvr58rMJ8)
--   SOLO ANNUAL  price_1TgAlxE5jzWcAIgedH5FM8No → 1790.00 PLN ✓ (prod_UbzUdnvr58rMJ8)
--   PRO  MONTHLY price_1TgAnSE5jzWcAIgeshZ6TqG8 → 299.00 PLN ✓ (prod_UbzUYzMQ28OCzt)
--   PRO  ANNUAL  price_1TgAqVE5jzWcAIgeOh1veVjP → 2990.00 PLN ✓ (prod_UbzUYzMQ28OCzt)

UPDATE subscription_plans
SET stripe_price_id = 'price_1TgAk2E5jzWcAIgeQ572wpkE'
WHERE tier  = 'SOLO'::plan_tier
  AND cycle = 'MONTHLY'::billing_cycle
  AND is_active = TRUE;

UPDATE subscription_plans
SET stripe_price_id = 'price_1TgAlxE5jzWcAIgedH5FM8No'
WHERE tier  = 'SOLO'::plan_tier
  AND cycle = 'ANNUAL'::billing_cycle
  AND is_active = TRUE;

UPDATE subscription_plans
SET stripe_price_id = 'price_1TgAnSE5jzWcAIgeshZ6TqG8'
WHERE tier  = 'PRO'::plan_tier
  AND cycle = 'MONTHLY'::billing_cycle
  AND is_active = TRUE;

UPDATE subscription_plans
SET stripe_price_id = 'price_1TgAqVE5jzWcAIgeOh1veVjP'
WHERE tier  = 'PRO'::plan_tier
  AND cycle = 'ANNUAL'::billing_cycle
  AND is_active = TRUE;
