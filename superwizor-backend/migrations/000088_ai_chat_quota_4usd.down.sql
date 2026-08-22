-- Powrót do $1.50. Nie usuwamy wiersza — 000084 go zasiał i to on jest
-- właścicielem jego istnienia.
UPDATE app_config
   SET value = '1500000',
       note  = 'Default monthly per-therapist chat budget in micro-USD. '
               '1500000 = $1.50 (decision D3, revisit after 30 days of data).'
 WHERE key = 'AI_CHAT_QUOTA_MICRO_USD'
   AND organization_id IS NULL;
