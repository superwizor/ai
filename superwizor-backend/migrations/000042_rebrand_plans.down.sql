-- Rollback: restore previous plan names and token quotas.

UPDATE subscription_plans
SET
    display_name          = 'Solo Monthly',
    tokens_per_period     = 20,
    marketing_description = 'Plan dla terapeutów indywidualnych — 20 sesji miesięcznie.'
WHERE tier = 'SOLO' AND cycle = 'MONTHLY' AND is_active = TRUE;

UPDATE subscription_plans
SET
    display_name          = 'Pro Monthly',
    tokens_per_period     = 40,
    marketing_description = 'Plan dla terapeutów intensywnie korzystających — 40 sesji miesięcznie.'
WHERE tier = 'PRO' AND cycle = 'MONTHLY' AND is_active = TRUE;

UPDATE subscription_plans
SET
    display_name          = 'Clinic Monthly (5 licenses)',
    tokens_per_period     = 150,
    marketing_description = 'Plan dla małych klinik — pula 150 sesji miesięcznie dzielona między 5 terapeutów.'
WHERE tier = 'CLINIC' AND cycle = 'MONTHLY' AND is_active = TRUE;
