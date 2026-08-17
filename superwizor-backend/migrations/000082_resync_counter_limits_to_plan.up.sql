-- Podnosi liczniki ORG-LEVEL otwartego okresu, które dają MNIEJ sesji,
-- niż obiecuje plan subskrypcji.
--
-- Dwa różne pochodzenia, ten sam skutek dla klienta:
--
-- 1. Skamielina katalogu. Migracje 000042 i 000048 jawnie pomijały
--    warianty ANNUAL ("deferred — pricing decision pending"), więc
--    PRO ANNUAL stało na 480, a SOLO ANNUAL na 240 aż do 000070, które
--    podniosło je do 1080 i 360 — ale ruszyło wyłącznie tabelę
--    subscription_plans. tokens_limit jest migawką z chwili powstania
--    licznika, nie odczytem planu na żywo, więc otwarte okresy zostały
--    na starych wartościach.
--
-- 2. Ręczne zaniżenie. AdminResetTokens przyjmuje dowolne
--    tokens_limit > 0 i nie porównuje go z planem; w gałęzi mintującej
--    (billing-svc .../grpc/admin.go) zakłada wiersz org-level z wartością
--    podaną przez operatora. Tak organizacja na planie PRO Monthly (90)
--    dostała 40 — wartość, która nie odpowiada żadnemu planowi.
--    Zgłoszone 2026-08-01 przez klienta, nie przez monitoring.
--
-- ZAKRES jest wąski celowo:
--
--   therapist_id IS NULL — licznik per-terapeutowy bierze limit z planu
--   JEGO MIEJSCA (docs/38), a nie z planu subskrypcji. Terapeuta na
--   miejscu SOLO (30) w organizacji na PRO (90) jest poprawny;
--   porównanie go z planem subskrypcji zawyżyłoby mu limit.
--
--   tokens_limit < tokens_per_period — twarda gwarancja, że migracja
--   nigdy nie obniża limitu. Rozjazdy w drugą stronę to świadome
--   nadania administracyjne (limit 50 przy planie 30 i 46 zużytych
--   sesjach); zrównanie ich z planem wyrzuciłoby klienta poniżej tego,
--   co już wykorzystał.
--
--   tier <> 'TRIAL' — liczniki trialowe są zakładane z realnym progiem
--   próbnym (3 lub 5), podczas gdy wiersz TRIAL w katalogu niesie 10.
--   Tam nieaktualny jest KATALOG, nie licznik. Bez tego warunku
--   migracja podniosłaby próg darmowy ~190 organizacjom (sprawdzone na
--   stagingu 2026-08-01).
--
--   period_end > now() — okresy zamknięte są zapisem historycznym
--   rozliczenia i nie wolno ich przepisywać.

UPDATE usage_counters c
SET tokens_limit = p.tokens_per_period,
    updated_at   = now()
FROM subscriptions s
JOIN subscription_plans p ON p.id = s.plan_id
WHERE c.subscription_id = s.id
  AND c.therapist_id IS NULL
  AND c.period_end > now()
  AND p.tier <> 'TRIAL'
  AND c.tokens_limit < p.tokens_per_period;
