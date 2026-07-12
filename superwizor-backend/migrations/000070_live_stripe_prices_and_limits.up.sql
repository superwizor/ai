-- Wyrównanie cennika do finalnych wartości produkcyjnych (cennik Marcin, lipiec 2026).
-- SOLO → Równowaga, PRO → Rozkwit
--
-- Zmiany:
--   SOLO Monthly:  cena 149→149 (bez zmian), tokeny 20→30, display_name, stripe_price_id (live)
--   SOLO Annual:   cena 1490→1490 (bez zmian), tokeny 240→360, display_name, stripe_price_id (live)
--   PRO  Monthly:  cena 249→299, tokeny 40→90, display_name, stripe_price_id (live)
--   PRO  Annual:   cena 2490→2990, tokeny 480→1080, display_name, stripe_price_id (live)
--   CLINIC:        deaktywacja (is_active = false) — nie ma w cenniku Marcina

BEGIN;

UPDATE subscription_plans SET
    price_gross = 149.00,
    tokens_per_period = 30,
    display_name = 'Równowaga Monthly',
    stripe_price_id = 'price_1TsUvXEA7Lw46kANXxzZZwTs'
WHERE tier = 'SOLO' AND cycle = 'MONTHLY';

UPDATE subscription_plans SET
    price_gross = 1490.00,
    tokens_per_period = 360,
    display_name = 'Równowaga Annual',
    stripe_price_id = 'price_1TsUvlEA7Lw46kANGuLjnoeD'
WHERE tier = 'SOLO' AND cycle = 'ANNUAL';

UPDATE subscription_plans SET
    price_gross = 299.00,
    tokens_per_period = 90,
    display_name = 'Rozkwit Monthly',
    stripe_price_id = 'price_1TsUwUEA7Lw46kANHgjOrNRy'
WHERE tier = 'PRO' AND cycle = 'MONTHLY';

UPDATE subscription_plans SET
    price_gross = 2990.00,
    tokens_per_period = 1080,
    display_name = 'Rozkwit Annual',
    stripe_price_id = 'price_1TsUwkEA7Lw46kAN76gYZGIQ'
WHERE tier = 'PRO' AND cycle = 'ANNUAL';

-- Deaktywacja planu CLINIC (nie ma w cenniku Marcina).
UPDATE subscription_plans SET is_active = false
WHERE tier = 'CLINIC';

COMMIT;
