-- 000048: Realign plan catalog with pricing decision 2026-06-08.
--
-- Changes:
--   1. TRIAL: tokens_per_period 3 → 5 (5 sessions / 30 days free trial)
--   2. SOLO MONTHLY: rebrand to "Równowaga", tokens 5→30, price 0→179.00 PLN brutto
--   3. PRO MONTHLY: rebrand to "Rozkwit", tokens 30→90, price 0→299.00 PLN brutto
--   4. Add BETA enum value to plan_tier
--   5. Seed BETA plan: 120 tokens/period, 0 PLN, MONTHLY
--
-- Note: ANNUAL variants are deferred — pricing decision pending.
-- Note: Existing trial subscriptions keep their old 3-token limit in
--       usage_counters. Only new signups get the new 5-token limit.
--       To backfill existing users, run:
--         UPDATE usage_counters SET tokens_limit = 5
--         WHERE subscription_id IN (
--           SELECT s.id FROM subscriptions s
--           JOIN subscription_plans sp ON s.plan_id = sp.id
--           WHERE sp.tier = 'TRIAL' AND s.status = 'TRIALING'
--         );

-- 1. TRIAL: 3 → 5 tokens
UPDATE subscription_plans
SET tokens_per_period     = 5,
    marketing_description = 'Bezpłatny trial — 5 sesji przez 30 dni. Bez karty kredytowej.'
WHERE tier = 'TRIAL' AND cycle = 'MONTHLY' AND is_active = TRUE;

-- 2. SOLO MONTHLY → Równowaga (30 sessions, 179 PLN brutto)
UPDATE subscription_plans
SET display_name          = 'Równowaga',
    tokens_per_period     = 30,
    price_gross           = 179.00,
    marketing_description = 'Plan Równowaga — 30 sesji miesięcznie. 179 zł brutto.'
WHERE tier = 'SOLO' AND cycle = 'MONTHLY' AND is_active = TRUE;

-- 3. PRO MONTHLY → Rozkwit (90 sessions, 299 PLN brutto)
UPDATE subscription_plans
SET display_name          = 'Rozkwit',
    tokens_per_period     = 90,
    price_gross           = 299.00,
    marketing_description = 'Plan Rozkwit — 90 sesji miesięcznie. 299 zł brutto.'
WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = TRUE;

-- 4. Add BETA to plan_tier enum (IF NOT EXISTS = safe for re-runs)
ALTER TYPE plan_tier ADD VALUE IF NOT EXISTS 'BETA';
