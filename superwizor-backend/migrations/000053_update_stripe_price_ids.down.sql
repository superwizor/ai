-- Rollback: restore old stripe_price_id values from migration 000039.
UPDATE subscription_plans
SET stripe_price_id = 'price_1TclVgE5jzWcAIgeT6ec0HDh'
WHERE tier  = 'SOLO'::plan_tier
  AND cycle = 'MONTHLY'::billing_cycle
  AND is_active = TRUE;

UPDATE subscription_plans
SET stripe_price_id = 'price_1TclVhE5jzWcAIge7YjI49Hs'
WHERE tier  = 'SOLO'::plan_tier
  AND cycle = 'ANNUAL'::billing_cycle
  AND is_active = TRUE;

UPDATE subscription_plans
SET stripe_price_id = 'price_1TclVhE5jzWcAIgeMQTPps4i'
WHERE tier  = 'PRO'::plan_tier
  AND cycle = 'MONTHLY'::billing_cycle
  AND is_active = TRUE;

UPDATE subscription_plans
SET stripe_price_id = 'price_1TclViE5jzWcAIgehEFNihUP'
WHERE tier  = 'PRO'::plan_tier
  AND cycle = 'ANNUAL'::billing_cycle
  AND is_active = TRUE;
