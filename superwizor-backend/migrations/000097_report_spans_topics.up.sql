-- 000097: hasła tematyczne spanu (plan F7a-1, dok. 65).
--
-- S1 zwraca dla każdego spanu `topics` — 1–3 hasła w mianowniku, których
-- JEDYNYM zadaniem jest liczenie powtórzeń w S1.5. Do tej migracji hasła
-- ginęły zaraz po przebiegu: składowaliśmy WYNIKOWE wzorce
-- (report_patterns), a nie materiał, z którego powstały.
--
-- ══ Dlaczego to blokuje wnioskowanie podłużne ══
--
-- Rekurencja MIĘDZY sesjami liczy się na sumie haseł z wielu sesji.
-- Bez składowanych haseł jedyną drogą byłoby ponowne przetwarzanie
-- starych transkrypcji przy każdym raporcie — czyli koszt rosnący
-- kwadratowo i wynik zależny od wersji promptu S1 z dnia przeliczenia.
--
-- Skutek uboczny, który już dziś widać w raportach: model pisze
-- „temat wraca trzeci raz" o rekurencji międzysesyjnej, S1.5 jej nie
-- widzi (liczy w obrębie jednej sesji), więc V5 słusznie kasuje
-- wzmiankę. Zdanie było prawdziwe klinicznie i niepoliczalne technicznie.
--
-- ══ Historia sprzed migracji ══
--
-- Stare spany dostają pustą tablicę i UCZCIWIE nie liczą się do
-- rekurencji. Nie dorabiamy haseł wstecz: wymagałoby to przepuszczenia
-- archiwalnych transkrypcji przez dzisiejszy prompt S1, a wtedy wzorzec
-- „policzony" dla sesji sprzed pół roku zależałby od wersji promptu z
-- dnia przeliczenia, nie z dnia sesji.
--
-- ══ Dlaczego bez indeksu ══
--
-- Okno międzysesyjne czyta spany PO SESJI (`session_id = ANY(...)`), a
-- hasła agreguje w kodzie. Indeks GIN po `topics` kosztowałby przy
-- każdym zapisie S1 (setki spanów na sesję) i nie miałby dziś czytelnika.
-- Wchodzi dopiero, gdy pojawi się zapytanie „znajdź sesje po haśle".

ALTER TABLE report_spans
    ADD COLUMN IF NOT EXISTS topics TEXT[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN report_spans.topics IS
    'Hasła tematyczne z S1 (1–3, mianownik). Wejście rekurencji '
    'międzysesyjnej w S1.5. Puste dla spanów sprzed migracji 000097 — '
    'takie spany nie liczą się do rekurencji i nie są uzupełniane wstecz.';
