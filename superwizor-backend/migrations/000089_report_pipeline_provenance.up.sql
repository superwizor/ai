-- Slad potoku na raporcie (plan 16, sekcja 2.3; dok. 11 sekcja 7).
--
-- Kazdy raport ma powiedziec, CZYM powstal. Bez tego nie ma ani
-- odtwarzalnosci do audytu (art. 94 MDR), ani porownania wersji w
-- benchmarku, ani mozliwosci odrozniania raportow eksperymentalnych od
-- produkcyjnych po fakcie.
--
-- DEFAULT 'legacy' zalatwia migracje historii: dotychczasowe raporty
-- powstaly starym potokiem i nie sa przepisywane.

ALTER TABLE reports
    ADD COLUMN IF NOT EXISTS pipeline_version  TEXT NOT NULL DEFAULT 'legacy',
    -- 'legacy' | 'ontology_s1s5' | 'ontology_s1s5_experimental'
    ADD COLUMN IF NOT EXISTS ontology_version  TEXT,
    -- semver uzytej wersji ontologii; NULL dla legacy
    ADD COLUMN IF NOT EXISTS prompt_versions   JSONB,
    -- {"s1":"...","s2":"...","s2b":"...","s4":"...","s5":"..."}
    ADD COLUMN IF NOT EXISTS validator_version TEXT;
    -- wersja regul R1-R10

-- Indeks pod dwa zapytania, ktore beda czeste: panel Jakosci filtruje
-- raporty per potok, a statystyki czatu (A2/A6) musza WYKLUCZAC raporty
-- eksperymentalne z licznika ReportsAvailable.
CREATE INDEX IF NOT EXISTS idx_reports_pipeline
    ON reports(pipeline_version, created_at DESC);

COMMENT ON COLUMN reports.pipeline_version IS
    'Ktorym potokiem powstal raport. Raporty *_experimental nie licza sie '
    'do ReportsAvailable i nie wyzwalaja powiadomien (plan 16 sekcja 2.5).';
