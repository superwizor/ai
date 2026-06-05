-- Rebrand commercial plan names and update token quotas (2026-06-05).
--
-- New plan lineup:
--   Poznanie  (SOLO  MONTHLY) — 5 tokens / 30 days   [entry]
--   Równowaga (PRO   MONTHLY) — 30 tokens / month     [mid]
--   Rozkwit   (CLINIC MONTHLY)— 120 tokens / month    [high]
--
-- EN equivalents: Discovery / Balance / Flourishing
--
-- Only MONTHLY rows are updated; ANNUAL variants left for a follow-up
-- pricing decision. TRIAL plan is untouched.
-- The tier enum values (SOLO / PRO / CLINIC) are internal identifiers
-- and do not change.

UPDATE subscription_plans
SET
    display_name          = 'Poznanie',
    tokens_per_period     = 5,
    marketing_description = 'Plan wstępny — 5 sesji przez 30 dni. Idealne na start.'
WHERE tier = 'SOLO' AND cycle = 'MONTHLY' AND is_active = TRUE;

UPDATE subscription_plans
SET
    display_name          = 'Równowaga',
    tokens_per_period     = 30,
    marketing_description = 'Plan regularny — 30 sesji miesięcznie.'
WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = TRUE;

UPDATE subscription_plans
SET
    display_name          = 'Rozkwit',
    tokens_per_period     = 120,
    marketing_description = 'Plan premium — do 120 sesji miesięcznie.'
WHERE tier = 'CLINIC' AND cycle = 'MONTHLY' AND is_active = TRUE;
