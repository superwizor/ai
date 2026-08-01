-- Świadomy no-op.
--
-- 000082 podnosi tokens_limit do wartości z planu, nie zapisując
-- wartości poprzedniej. Po migracji licznik z limitem 90 na planie PRO
-- Monthly jest nieodróżnialny od licznika, który miał 90 od początku —
-- a poprzednie wartości miały dwa różne pochodzenia (skamielina
-- katalogu 480/240 oraz ręcznie wpisane 40), więc nie da się ich
-- odtworzyć z samego stanu tabeli.
--
-- Zgadywane cofnięcie byłoby gorsze niż żadne: obniża limit, więc
-- klient z zużyciem powyżej starej wartości natychmiast znalazłby się
-- ponad limitem i stracił możliwość nagrywania. Jeśli cofnięcie jest
-- naprawdę potrzebne, właściwą drogą jest AdminResetTokens na
-- konkretnej organizacji — z wpisem w audit_events, którego migracja
-- by nie zostawiła.

SELECT 1;
