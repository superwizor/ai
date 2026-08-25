-- 000099: semantyczny indeks wnioskowania (plan F7b-1, dok. 65 §5.1).
--
-- F7a dało potokowi okno: trzy ostatnie sesje, wybierane po dacie. To
-- wystarcza na ciągłość bieżącej pracy i ożywia próg
-- `min_evidence.sessions`, ale gubi dokładnie to, po co terapeuta
-- czyta raport po pół roku: ustalenie z sesji trzeciej, które właśnie
-- wróciło w dziewiętnastej.
--
-- ══ Dlaczego indeksujemy TWIERDZENIA I HIPOTEZY, a nie tekstu ══
--
-- Klasyczny RAG tnie dokument na kawałki i szuka po nich. Tutaj
-- jednostką jest byt, który PRZESZEDŁ POTOK: twierdzenie ma za sobą
-- spany ze zweryfikowanymi mechanicznie cytatami, hipoteza — swoje
-- twierdzenie źródłowe. Wyszukiwanie jest więc wyłącznie ADRESOWANIEM:
-- co znajdziemy, przynosi ze sobą własne kotwice dowodowe. To jest
-- powód, dla którego semantyka nie łamie tu fundamentu architektury,
-- choć sama w sobie jest niedeterministyczna.
--
-- ══ Poziomy się NIE MIESZAJĄ (dok. 65 §N1) ══
--
-- Kolumna `kind` rozdziela 'claim' od 'hypothesis' już na zapisie, a nie
-- dopiero w zapytaniu. Przeszła hipoteza NIGDY nie jest dowodem —
-- wchodzi wyłącznie do kanału ciągłości, z własnym sufitem statusu.
-- Gdyby oba poziomy leżały w jednym worku, pierwsze zapytanie, które
-- o tym zapomni, zamieni powtórzoną interpretację w uzasadnienie.
--
-- ══ Klasa potoku jest KOLUMNĄ, nie konwencją ══
--
-- Raport produkcyjny nie ma prawa zobaczyć twierdzeń ze szkicu
-- ontologii, którego eksperci nie zatwierdzili — a szkic kalibruje się
-- właśnie na własnej historii. Dlatego indeksujemy OBIE klasy i
-- rozdzielamy je `pipeline_version` przy odczycie. To inna decyzja niż
-- przy rag_memories (tamta tabela nie zna klas, więc raporty
-- eksperymentalne w ogóle do niej nie piszą) i musi taka być, bo tamten
-- indeks czyta potok legacy, a ten — ontologiczny.
--
-- ══ Model embeddingów jest CZĘŚCIĄ DANYCH (dok. 65 §N3) ══
--
-- Wektory z dwóch różnych modeli leżą w różnych przestrzeniach i ich
-- podobieństwo nie znaczy nic. Zapisujemy więc, czym policzono każdy
-- wiersz: zmiana modelu przestaje być cichą zmianą wyników i staje się
-- pytaniem „co zrobić ze starymi wierszami".
--
-- Prywatność: bez nowych powierzchni (§N5). Wektory i szyfrogram leżą
-- w tej samej instancji co reszta materiału klinicznego, tekst jest
-- pochodną transkrypcji już spseudonimizowanej (docs/41), a spany
-- ryzyka (T22) nie mają jak tu trafić — nie zasilają twierdzeń.

CREATE TABLE report_inference_index (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    patient_file_id     UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    session_id          UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    -- Kasowanie raportu zabiera jego wiersze indeksu. Bez tego usunięty
    -- raport dalej podpowiadałby przyszłym przebiegom — a jego treść
    -- właśnie uznano za niebyłą.
    report_id           UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,

    -- 'claim' | 'hypothesis' — patrz nagłówek.
    kind                VARCHAR(16) NOT NULL,
    source_claim_id     UUID REFERENCES report_claims(id) ON DELETE CASCADE,
    -- Stabilny adres bytu W OBRĘBIE raportu: identyfikator twierdzenia
    -- albo hipotezy ('A', 'B'). Klucz idempotencji — szyfrogram się do
    -- tego nie nadaje, bo koperta jest z definicji niedeterministyczna
    -- i to samo zdanie zapisane dwa razy dałoby dwa różne bajty.
    item_ref            TEXT NOT NULL,

    construct_id        TEXT NOT NULL,
    epistemic_status    TEXT NOT NULL,
    confidence          REAL,
    pipeline_version    TEXT NOT NULL,

    -- Migawka tekstu, na którym policzono wektor. Szyfrowana kopertowo
    -- jak każda treść kliniczna. Migawka, a nie odnośnik: tekst
    -- twierdzenia może zniknąć razem z raportem, a wektor bez tekstu
    -- jest nieczytelny przy audycie.
    text_ciphertext     BYTEA NOT NULL,
    text_encrypted_dek  BYTEA NOT NULL,

    embedding           vector(768) NOT NULL,
    embedding_model     TEXT NOT NULL,

    session_at          DATE NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Izolacja kartotek jest warunkiem TWARDYM, nie optymalizacją: każde
-- zapytanie zawęża się do jednej kartoteki, więc klucz zaczyna się od
-- niej.
CREATE INDEX idx_inference_scope
    ON report_inference_index(patient_file_id, kind, pipeline_version, session_at DESC);

-- HNSW z miarą kosinusową — ta sama, co w rag_memories, żeby progi
-- podobieństwa znaczyły to samo w obu miejscach.
CREATE INDEX idx_inference_ann
    ON report_inference_index USING hnsw (embedding vector_cosine_ops);

-- Ten sam byt nie ma być indeksowany dwa razy przy ponowieniu
-- przebiegu (Pub/Sub potrafi dostarczyć zdarzenie powtórnie).
CREATE UNIQUE INDEX idx_inference_unikalny
    ON report_inference_index(report_id, kind, item_ref);

COMMENT ON COLUMN report_inference_index.kind IS
    'claim = twierdzenie po walidacji S3 (może być dowodem). '
    'hypothesis = proza S4 (NIGDY dowodem — wyłącznie kanał ciągłości).';
COMMENT ON COLUMN report_inference_index.pipeline_version IS
    'Klasa potoku. Odczyt MUSI filtrować: raport produkcyjny nie widzi '
    'twierdzeń ze szkicu ontologii, a szkic kalibruje się na własnej '
    'historii.';
COMMENT ON COLUMN report_inference_index.embedding_model IS
    'Wektory z różnych modeli leżą w różnych przestrzeniach — bez tej '
    'kolumny zmiana modelu cicho zmieniałaby wyniki wyszukiwania.';
