-- Rollback: revert to pre-live values (migration 000029 originals + sandbox price IDs).

BEGIN;

UPDATE subscription_plans SET
    price_gross = 149.00,
    tokens_per_period = 20,
    display_name = 'Solo Monthly',
    stripe_price_id = 'price_1TclVgE5jzWcAIgeT6ec0HDh'
WHERE tier = 'SOLO' AND cycle = 'MONTHLY';

UPDATE subscription_plans SET
    price_gross = 1490.00,
    tokens_per_period = 240,
    display_name = 'Solo Annual',
    stripe_price_id = 'price_1TclVhE5jzWcAIge7YjI49Hs'
WHERE tier = 'SOLO' AND cycle = 'ANNUAL';

UPDATE subscription_plans SET
    price_gross = 249.00,
    tokens_per_period = 40,
    display_name = 'Pro Monthly',
    stripe_price_id = 'price_1TclVhE5jzWcAIgeMQTPps4i'
WHERE tier = 'PRO' AND cycle = 'MONTHLY';

UPDATE subscription_plans SET
    price_gross = 2490.00,
    tokens_per_period = 480,
    display_name = 'Pro Annual',
    stripe_price_id = 'price_1TclViE5jzWcAIgehEFNihUP'
WHERE tier = 'PRO' AND cycle = 'ANNUAL';

UPDATE subscription_plans SET is_active = true
WHERE tier = 'CLINIC';

COMMIT;
