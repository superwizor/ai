-- Seed the TRIAL plan row. Run in its own migration because Postgres
-- requires the enum value (added in 000032) to be committed before it
-- can be referenced in another statement.
--
-- Pricing: 0 PLN — free 3-token trial.
-- licenses_limit: 1 — solo therapist only; clinic upgrade happens
--                     out-of-band by switching to CLINIC plan.
-- has_b2b_dashboard: FALSE.
--
-- The single-shot semantics (no auto-renewal) are enforced by:
--   - identity-svc.CreateUser bootstrap sets period_end ~100 years out
--   - billing-svc /admin/manual-period-renewal cron skips tier='TRIAL'
-- The unique INDEX on (tier, cycle) is partial (WHERE is_active=TRUE),
-- so ON CONFLICT can't reference it. Migrations only run once, so a
-- plain INSERT is fine — re-running this migration would never happen
-- in practice. NOT EXISTS guard keeps the migration idempotent for
-- the local dev case where someone re-applies by hand.
INSERT INTO subscription_plans (
    tier, cycle, display_name, price_gross, currency_code,
    tokens_per_period, licenses_limit, has_b2b_dashboard,
    marketing_description, is_active
)
SELECT
    'TRIAL', 'MONTHLY', 'Trial', 0.00, 'PLN',
    3, 1, FALSE,
    'Bezpłatny trial — 3 sesje na start. Aby kontynuować, wybierz plan SOLO, PRO lub CLINIC.', TRUE
WHERE NOT EXISTS (
    SELECT 1 FROM subscription_plans
    WHERE tier = 'TRIAL' AND cycle = 'MONTHLY' AND is_active = TRUE
);
