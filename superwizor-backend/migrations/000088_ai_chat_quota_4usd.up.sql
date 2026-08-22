-- Miesięczny budżet czatu AI na terapeutę: $1.50 → $4.00.
--
-- Wartość z migracji 000084 (1500000) była opisana jako „decision D3,
-- revisit after 30 days of data". Dane są: pomiar 21.08.2026 dał ok.
-- 2900–3700 µUSD na turę zależnie od długości soczewki modalności, czyli
-- ok. 400–520 tur miesięcznie przy starym limicie. Po rozszerzeniu
-- soczewek do 9000 znaków (ontologie modalności) sufit robił się ciasny.
--
-- 4000000 µUSD = $4.00 ≈ 1100–1400 tur miesięcznie na terapeutę.
--
-- Zmieniamy WIERSZ GLOBALNY (organization_id IS NULL). Kolejność
-- rozstrzygania w pkg/appconfig to: wiersz organizacji → wiersz globalny
-- → stała w kodzie, więc organizacje z własnym nadpisaniem zostają przy
-- swoim — i tak ma być, bo nadpisanie jest świadomą decyzją operatora.
-- Stała w kodzie idzie w tym samym commicie, żeby świeże środowisko
-- startowało z tą samą liczbą.
UPDATE app_config
   SET value = '4000000',
       note  = 'Default monthly per-therapist chat budget in micro-USD. '
               '4000000 = $4.00 (podniesione 22.08.2026 z 1500000 po '
               'pomiarze kosztu tury i rozszerzeniu soczewek do 9000 znaków).'
 WHERE key = 'AI_CHAT_QUOTA_MICRO_USD'
   AND organization_id IS NULL;

-- Gdyby wiersza globalnego nie było (środowisko postawione bez seeda
-- z 000084), zakładamy go — inaczej limit spadłby cicho na stałą z kodu.
INSERT INTO app_config (key, value, note)
SELECT 'AI_CHAT_QUOTA_MICRO_USD', '4000000',
       'Default monthly per-therapist chat budget in micro-USD. 4000000 = $4.00.'
 WHERE NOT EXISTS (
     SELECT 1 FROM app_config
      WHERE key = 'AI_CHAT_QUOTA_MICRO_USD' AND organization_id IS NULL
 );
