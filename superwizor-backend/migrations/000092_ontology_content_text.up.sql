-- Tresc ontologii jako TEKST, nie JSONB — korekta 000090.
--
-- 000090 deklarowalo `content JSONB` z uzasadnieniem, ze panel Jakosci i
-- benchmark odpytaja pojedyncze konstrukty bez parsowania calosci w Go.
-- To uzasadnienie bylo blednie wazone: aby cokolwiek odpytac, YAML
-- musialby zostac skonwertowany do JSON-a przy zapisie, a konwersja
-- ZJADA KOMENTARZE.
--
-- Komentarze w tych plikach nie sa ozdoba. Seedy PPT i CBT nios(a
-- "ZWERYFIKOWAC z ekspertem", "PLACEHOLDER", odnotowana rozbieznosc
-- katalogow miedzy dokumentem 11 a soczewka czatu i uzasadnienia
-- mapowan antybledowych. To jest material roboczy sesji autoryzacyjnej
-- (D2) — utrata tych adnotacji kosztowalaby wiecej niz wygoda zapytan.
--
-- Odpytywanie konstruktow, gdy bedzie potrzebne, robi sie z pola
-- construct_count i z parsowania w pkg/ontology, ktore i tak zachodzi
-- przy kazdym zapisie (walidacja metaschematem).
--
-- Konwersja bezpieczna: kolumna nie ma jeszcze zadnych wierszy —
-- pierwszy import seedow padl wlasnie na tym bledzie.

ALTER TABLE ontology_versions
    ALTER COLUMN content TYPE TEXT USING content #>> '{}';

-- Liczba konstruktow liczona przy zapisie (Go zna ja po walidacji),
-- zeby lista wersji w Studiu nie parsowala YAML-a per wiersz.
ALTER TABLE ontology_versions
    ADD COLUMN IF NOT EXISTS construct_count INT NOT NULL DEFAULT 0;

COMMENT ON COLUMN ontology_versions.content IS
    'Tresc ontologii w YAML, doslownie — z komentarzami. Zrodlem prawdy o '
    'strukturze jest pkg/ontology, nie typ kolumny.';
