-- 000049: Seed BETA plan row.
--
-- Must be a separate migration from 000048 because Postgres requires
-- the ALTER TYPE ADD VALUE to be committed before the new value can
-- be referenced in DML. Same pattern as 000032 + 000033 for TRIAL.
--
-- BETA plan: 120 tokens/period (1 month), 0 PLN, for 50 invited testers.
-- Beta subscriptions have 2 × 30-day periods (handled by cron
-- auto-renewal logic, not by this migration).

INSERT INTO subscription_plans (
    tier, cycle, display_name, price_gross, currency_code,
    tokens_per_period, licenses_limit, has_b2b_dashboard,
    marketing_description, is_active
)
SELECT
    'BETA', 'MONTHLY', 'Beta', 0.00, 'PLN',
    120, 1, FALSE,
    'Program Beta — 120 sesji miesięcznie przez 2 miesiące. Zamknięta grupa 50 terapeutów.', TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM subscription_plans
    WHERE tier = 'BETA' AND cycle = 'MONTHLY' AND is_active = TRUE
);
