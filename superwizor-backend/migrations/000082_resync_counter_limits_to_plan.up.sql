-- Brakująca połowa migracji 000070.
--
-- 000070 przecenił katalog planów (PRO Monthly 40→90, PRO Annual
-- 480→1080, SOLO Annual 240→360), ale ruszył wyłącznie tabelę
-- subscription_plans. Wiersze usage_counters utworzone WCZEŚNIEJ
-- zachowały stary limit — tokens_limit jest migawką z chwili powstania
-- licznika, nie odczytem planu na żywo. Odnowienie okresu bierze limit
-- z planu (renewOneSubscription), więc rozjazd sam znika na granicy
-- okresu; do tego czasu klient przez cały miesiąc widzi mniej sesji,
-- niż mu się należy.
--
-- Zgłoszone 2026-08-01: organizacja na planie PRO Monthly (90 sesji)
-- pokazywała limit 40 — czyli dokładnie starą wartość katalogową.
--
-- ZAKRES jest celowo wąski. Aktualizujemy tylko te liczniki, których
-- limit to DOKŁADNIE przed-000070 wartość katalogowa dla ich planu.
-- Rozjazdy o innej wartości to świadome nadania administracyjne
-- (limit 50 przy planie 30 i 46 zużytych sesjach) — zrównanie ich
-- z planem obcięłoby klienta PONIŻEJ tego, co już wykorzystał.
-- Ten warunek nigdy nie obniża limitu: wszystkie trzy pary idą w górę.
--
-- Dotyczy wyłącznie okresów OTWARTYCH (period_end > now()). Okresy
-- zamknięte są zapisem historycznym rozliczenia i nie wolno ich
-- przepisywać.

UPDATE usage_counters c
SET tokens_limit = p.tokens_per_period,
    updated_at   = now()
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
WHERE c.subscription_id = s.id
  AND c.period_end > now()
  AND (p.tier::text, p.cycle::text, c.tokens_limit) IN (
        ('PRO',  'MONTHLY', 40),
        ('PRO',  'ANNUAL',  480),
        ('SOLO', 'ANNUAL',  240)
      );
