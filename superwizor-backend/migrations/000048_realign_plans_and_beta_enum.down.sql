-- Revert plan catalog to pre-000048 state.

-- 1. TRIAL: 5 → 3 tokens
UPDATE subscription_plans
SET tokens_per_period     = 3,
    marketing_description = 'Bezpłatny trial — 3 sesje na start. Aby kontynuować, wybierz plan SOLO, PRO lub CLINIC.'
WHERE tier = 'TRIAL' AND cycle = 'MONTHLY' AND is_active = TRUE;

-- 2. SOLO MONTHLY: revert to Poznanie / 5 tokens
UPDATE subscription_plans
SET display_name          = 'Poznanie',
    tokens_per_period     = 5,
    price_gross           = 0.00,
    marketing_description = 'Plan wstępny — 5 sesji przez 30 dni. Idealne na start.'
WHERE tier = 'SOLO' AND cycle = 'MONTHLY' AND is_active = TRUE;

-- 3. PRO MONTHLY: revert to Równowaga / 30 tokens
UPDATE subscription_plans
SET display_name          = 'Równowaga',
    tokens_per_period     = 30,
    price_gross           = 0.00,
    marketing_description = 'Plan regularny — 30 sesji miesięcznie.'
WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = TRUE;

-- Cannot DROP enum value in Postgres — BETA stays in enum but plan is deactivated by 000049.down.
