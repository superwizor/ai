-- Spany i twierdzenia potoku S1-S5 (plan 16, ticket T4; dok. 11 §7).
--
-- Raport przestaje byc blokiem tekstu, a staje sie GRAFEM TWIERDZEN z
-- proweniencja do zrodla. To jest warunek trzech rzeczy naraz:
-- klikalnych cytatow w UI, odtwarzalnosci do audytu (art. 94 MDR) i
-- benchmarku, ktory porownuje wersje ontologii na tym samym materiale.

-- ── SPANY (wynik S1) ──
--
-- Cytat to doslowna wypowiedz klienta, czyli material kliniczny. Szyfrowany
-- kopertowo jak transcript_segments (000007): ciphertext + DEK per wiersz.
-- Kolumny NIESZYFROWANE to wylacznie metadane strukturalne — bez nich
-- walidator musialby deszyfrowac kazdy span, zeby sprawdzic prog.
CREATE TABLE report_spans (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    transcript_id       UUID NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,

    -- Identyfikator uzywany w odnosnikach twierdzen. Stabilny w obrebie
    -- transkrypcji, bo trafia do proweniencji zapisanych raportow.
    span_ref            TEXT NOT NULL,

    quote_ciphertext    BYTEA NOT NULL,
    quote_encrypted_dek BYTEA NOT NULL,

    ts_start_ms         INTEGER,
    ts_end_ms           INTEGER,
    speaker             VARCHAR(50),

    -- 'declarative' | 'behavioral' — wymog dowodowy R2, nie metadana:
    -- deklaracja "jestem punktualny" i opis "przyszedl 20 minut po
    -- czasie" nie sa tym samym rodzajem dowodu.
    kind                VARCHAR(20) NOT NULL DEFAULT 'declarative',
    -- 'self' | 'therapist' — obserwacja terapeuty O KLIENCIE jest
    -- legalnym dowodem i nie narusza R10.
    observed_by         VARCHAR(20) NOT NULL DEFAULT 'self',
    -- Span mowiacy WPROST o przeszlosci. Wylacznie taki moze uzasadnic
    -- twierdzenie etiologiczne (R5).
    about_past          BOOLEAN NOT NULL DEFAULT FALSE,
    -- Tresc ryzyka: span WYKLUCZONY z wnioskowania i ze statystyk S1.5
    -- (T22). Kolumna istnieje po to, zeby wykluczenie bylo zapisane, a
    -- nie liczone od nowa przy kazdym przebiegu.
    risk_content        BOOLEAN NOT NULL DEFAULT FALSE,
    -- Cisza przed spanem ze znacznikow chunkera 600 ms — wejscie dla
    -- wzorca `latency` (S1.5).
    silence_before_ms   INTEGER NOT NULL DEFAULT 0,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (transcript_id, span_ref)
);

CREATE INDEX idx_report_spans_session ON report_spans(session_id);
-- Indeks czesciowy: spany ryzyka sa odsiewane przy KAZDYM odczycie do
-- wnioskowania, wiec warunek nalezy do indeksu, nie do zapytania.
CREATE INDEX idx_report_spans_usable
    ON report_spans(transcript_id) WHERE risk_content = FALSE;

-- ── TWIERDZENIA (wynik S2 po walidacji S3) ──
CREATE TABLE report_claims (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id           UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,

    construct_id        TEXT NOT NULL,
    -- Tablica, bo multi_label (M2) dopuszcza kilka etykiet na twierdzenie.
    -- Pusta dla konstruktow bez katalogu zamknietego.
    categories          TEXT[] NOT NULL DEFAULT '{}',
    epistemic_status    TEXT NOT NULL,
    confidence          NUMERIC(4, 3),

    -- Uzasadnienie odnosi sie do materialu klienta, wiec szyfrowane.
    reasoning_ciphertext    BYTEA,
    reasoning_encrypted_dek BYTEA,

    -- Etykiety wejsciowe walidatora, zapisane po to, by dalo sie
    -- odtworzyc, DLACZEGO twierdzenie przeszlo lub nie.
    is_etiological      BOOLEAN NOT NULL DEFAULT FALSE,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_report_claims_report ON report_claims(report_id);
CREATE INDEX idx_report_claims_construct ON report_claims(construct_id);

-- ── PROWENIENCJA: twierdzenie -> span ──
--
-- Tabela laczaca, nie kolumna tablicowa: dowod i KONTRDOWOD to dwie
-- rozne relacje tego samego rodzaju, a format przestrzeni hipotez
-- (dok. 11 §5) renderuje je osobno ("dane za" / "dane przeciw").
CREATE TABLE report_claim_evidence (
    claim_id    UUID NOT NULL REFERENCES report_claims(id) ON DELETE CASCADE,
    span_id     UUID NOT NULL REFERENCES report_spans(id) ON DELETE RESTRICT,
    -- 'support' | 'counter'
    role        VARCHAR(10) NOT NULL DEFAULT 'support',
    PRIMARY KEY (claim_id, span_id, role)
);

CREATE INDEX idx_claim_evidence_span ON report_claim_evidence(span_id);

-- ── WZORCE (wynik S1.5) ──
--
-- Wzorzec jest DOWODEM, nie twierdzeniem — moze byc cytowany w
-- evidence na rowni ze spanem. Trzymamy metode i jej wersje, bo bez nich
-- nie da sie odtworzyc, czemu raport sprzed miesiaca widzial wzorzec,
-- ktorego dzisiejszy nie widzi.
CREATE TABLE report_patterns (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id       UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,

    pattern_ref     TEXT NOT NULL,
    pattern_type    TEXT NOT NULL,
    topics          TEXT[] NOT NULL DEFAULT '{}',
    method          TEXT NOT NULL,
    method_version  TEXT NOT NULL,
    sessions_count  INTEGER NOT NULL DEFAULT 0,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (report_id, pattern_ref)
);

CREATE TABLE report_pattern_spans (
    pattern_id  UUID NOT NULL REFERENCES report_patterns(id) ON DELETE CASCADE,
    span_id     UUID NOT NULL REFERENCES report_spans(id) ON DELETE RESTRICT,
    PRIMARY KEY (pattern_id, span_id)
);

-- ── ODRZUCENIA (rejestr walidatora) ──
--
-- Odrzucenia sa DANYMI, nie logiem. Progi przegladu z dok. 11 §8.3
-- (R5 > 5% miesiecznie -> audyt promptu S2; no_fit > 10% kwartalnie ->
-- przeglad ekspercki ontologii) wymagaja zapytania, a nie grepa po
-- Cloud Logging. Bez tresci twierdzenia — sam kod reguly i konstrukt.
CREATE TABLE report_claim_rejections (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id       UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    construct_id    TEXT NOT NULL,
    rule            TEXT NOT NULL,
    detail          TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_claim_rejections_rule ON report_claim_rejections(rule, created_at DESC);
CREATE INDEX idx_claim_rejections_construct ON report_claim_rejections(construct_id);
