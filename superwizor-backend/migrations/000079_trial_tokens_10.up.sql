-- 000079: TRIAL tokens_per_period 5 → 10 (decyzja produktowa 2026-07-22).
--
-- Jak w 000048: zmiana dotyczy WYŁĄCZNIE nowych rejestracji — istniejące
-- subskrypcje TRIALING zachowują limit z momentu startu w usage_counters.
-- Ewentualny backfill zastanych triali (osobna, świadoma decyzja):
--   UPDATE usage_counters SET tokens_limit = 10
--   WHERE subscription_id IN (
--     SELECT s.id FROM subscriptions s
--     JOIN subscription_plans sp ON s.plan_id = sp.id
--     WHERE sp.tier = 'TRIAL' AND s.status = 'TRIALING'
--   );

UPDATE subscription_plans
SET tokens_per_period     = 10,
    marketing_description = 'Bezpłatny trial — 10 sesji przez 30 dni. Bez karty kredytowej.'
WHERE tier = 'TRIAL' AND cycle = 'MONTHLY' AND is_active = TRUE;
