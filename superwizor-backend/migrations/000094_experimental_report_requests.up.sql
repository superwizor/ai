-- 000094: raporty eksperymentalne — rejestr zamowien (plan 16 §2.5).
--
-- Raport eksperymentalny powstaje na ontologii BEZ autoryzacji ekspertow.
-- Nie zastepuje raportu produkcyjnego, nie trafia do panelu klienta, nie
-- wywoluje powiadomienia "Raport gotowy" i nie liczy sie do statystyk.
--
-- ══ Po co osobna tabela zamiast liczenia po `reports` ══
--
-- Dobowy limit ma dzialac PRZED generacja, a wiersz w `reports` powstaje
-- dopiero po niej. Liczenie po `reports` przepuscilo by dziesiec zamowien
-- zlozonych, zanim skonczy sie pierwsze — czyli dokladnie ten przypadek,
-- przed ktorym limit ma bronic (potok wieloetapowy na Pro jest drogi,
-- a dual-run podwaja koszt kazdej sesji).
--
-- Tabela jest przy okazji sladem audytowym: kto zamowil, na czym i na
-- ktorej wersji ontologii. Bez tego nie da sie odtworzyc, skad wzial sie
-- artefakt, ktory nie jest materialem klinicznym, ale zawiera tresc sesji.

CREATE TABLE experimental_report_requests (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    therapist_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    session_id          UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,

    -- Kod modalnosci UZYTEJ do generacji. Moze roznic sie od modalnosci
    -- kartoteki: "raport CBT dla kartoteki PPT" jest jednym z dwoch
    -- powodow istnienia tego trybu.
    modality_code       VARCHAR(20) NOT NULL,
    -- Wersja ontologii, na ktorej zbudowano raport — takze `draft`.
    -- NULL wylacznie wtedy, gdy zamowienie odpadlo przed wyborem wersji.
    ontology_version_id UUID REFERENCES ontology_versions(id) ON DELETE SET NULL,

    -- 'dual_run' (przelacznik w ustawieniach) | 'on_demand' (arkusz).
    -- Dwa wejscia obsluguja rozlaczne przypadki i maja rozny profil
    -- kosztowy, wiec licznik ma je rozroznic, choc limit jest wspolny.
    origin              VARCHAR(20) NOT NULL DEFAULT 'on_demand',

    -- Wypelniane po udanej generacji. NULL = zamowienie w locie albo
    -- nieudane; jedno i drugie LICZY SIE do limitu, bo jedno i drugie
    -- kosztowalo wywolania modelu.
    report_id           UUID REFERENCES reports(id) ON DELETE SET NULL,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT experimental_origin_known
        CHECK (origin IN ('dual_run', 'on_demand'))
);

-- Sciezka goraca: ile ten terapeuta zamowil dzisiaj.
CREATE INDEX idx_experimental_requests_daily
    ON experimental_report_requests(therapist_id, created_at DESC);

COMMENT ON TABLE experimental_report_requests IS
    'Zamowienia raportow eksperymentalnych (plan 16 §2.5). Liczone PRZED '
    'generacja, bo wiersz w reports powstaje dopiero po niej.';

COMMENT ON COLUMN experimental_report_requests.report_id IS
    'NULL dla zamowien w locie i nieudanych. Oba liczą sie do dobowego '
    'limitu — oba kosztowaly wywolania modelu.';
