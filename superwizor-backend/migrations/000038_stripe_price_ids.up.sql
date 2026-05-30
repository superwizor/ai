-- Wpisuje stripe_price_id dla planów Solo i Pro (Sandbox / test mode).
--
-- Wartości odpowiadają produktom/cenom stworzonym w Stripe Sandbox 2026-05-30:
--   Produkt SuperWizor Solo: prod_UbzUdnvr58rMJ8
--   Produkt SuperWizor Pro:  prod_UbzUYzMQ28OCzt
--
-- Plan CLINIC celowo NIE dostaje stripe_price_id — model B2B / manual provider.
-- Indywidualne wyceny i limity ustawiane są przez SUPERWIZOR_ADMIN na panelu.
--
-- WAŻNE: Te IDs dotyczą trybu TEST (Sandbox). Przed wdrożeniem produkcyjnym
-- należy uruchomić analogiczną migrację z kluczami live mode.

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
