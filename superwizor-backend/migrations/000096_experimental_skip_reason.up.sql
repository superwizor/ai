-- 000096: powód pominięcia raportu eksperymentalnego.
--
-- Terapeuta włącza przełącznik obiecujący raport przy KAŻDEJ nowej sesji.
-- Gdy raport nie powstaje, cisza jest dla niego nierozróżnialna od awarii
-- — i tak została odczytana przy pierwszym użyciu na produkcji
-- (2026-08-23): sesja dała jeden raport, właściciel konta uznał, że to
-- ten nowy, i pytał, czy ma wgrać nagranie ponownie.
--
-- Odmowa szła wtedy wyłącznie do logu. Log odpowiada na pytania nasze,
-- nie terapeuty — a pytanie „dlaczego jest jeden raport" zadaje on, na
-- ekranie sesji.
--
-- ══ Dlaczego wiersz, a nie samo powiadomienie ══
--
-- Powiadomienie jest zdarzeniem: mija. Ekran sesji odwiedza się także
-- tydzień później, więc powód musi być STANEM, który da się odpytać przy
-- każdym otwarciu.
--
-- ══ Pominięcie NIE zużywa limitu ══
--
-- Wiersz pominięcia trafia do tej samej tabeli co zamówienia, bo dotyczy
-- tej samej sprawy. Ale licznik dobowy MUSI go pomijać: inaczej odmowa
-- z powodu wyczerpanego limitu sama zużywałaby limit, a stan raz
-- osiągnięty nigdy by się nie odblokował. Zapytania liczące dopisują
-- `AND skip_reason IS NULL`.

ALTER TABLE experimental_report_requests
    -- 'daily_limit' | 'org_disabled'. NULL = prawdziwe zamówienie.
    ADD COLUMN IF NOT EXISTS skip_reason TEXT,
    -- Wartość istotna dla powodu (dla 'daily_limit' — obowiązujący limit).
    -- Tekst, nie liczba: kolejne powody mogą nieść co innego.
    ADD COLUMN IF NOT EXISTS skip_detail TEXT;

-- Ekran sesji pyta o NAJNOWSZE pominięcie dla sesji przy każdym otwarciu.
CREATE INDEX IF NOT EXISTS idx_experimental_skip_by_session
    ON experimental_report_requests(session_id, created_at DESC)
    WHERE skip_reason IS NOT NULL;

COMMENT ON COLUMN experimental_report_requests.skip_reason IS
    'Niepuste = raport NIE powstał mimo włączonego przełącznika. Takie '
    'wiersze NIE liczą się do dobowego limitu — inaczej odmowa z powodu '
    'limitu sama zużywałaby limit.';
