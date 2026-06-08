-- Deactivate (don't delete) the BETA plan.
UPDATE subscription_plans SET is_active = FALSE
WHERE tier = 'BETA' AND cycle = 'MONTHLY';
