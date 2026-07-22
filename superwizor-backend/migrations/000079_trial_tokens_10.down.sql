-- Revert TRIAL to the 000048 values (5 tokens).
UPDATE subscription_plans
SET tokens_per_period     = 5,
    marketing_description = 'Bezpłatny trial — 5 sesji przez 30 dni. Bez karty kredytowej.'
WHERE tier = 'TRIAL' AND cycle = 'MONTHLY' AND is_active = TRUE;
