-- 000098: kontekst międzysesyjny przebiegu (plan F7a-2, dok. 65 §N2).
--
-- Od F7a raport sesji N może widzieć ustalenia sesji wcześniejszych.
-- Ta tabela odpowiada na pytanie, które bez niej byłoby nieodpowiadalne:
-- CO DOKŁADNIE ten przebieg zobaczył.
--
-- ══ Dlaczego to jest warunek wdrożenia, a nie miła dodatkowa metryka ══
--
-- Selekcja kontekstu jest bramką decydującą o treści raportu. Dopóki
-- selekcja jest deterministyczna (okno W sesji wstecz), da się ją
-- odtworzyć z parametrów. Od F7b dochodzi wyszukiwanie semantyczne —
-- niedeterministyczne z natury, a jego BŁĘDY SĄ NIEME: brakujące
-- połączenie wygląda dokładnie jak brak połączenia. Bez zapisu wejścia
-- audyt raportu kończy się na „model widział coś z poprzednich sesji",
-- a strojenie retrievalu nie ma czego stroić.
--
-- Dlatego dok. 65 stawia N2 jako warunek twardy: bez tej tabeli nie
-- wdrażamy F7b w ogóle.
--
-- ══ Czego NIE pokazaliśmy, też jest proweniencją ══
--
-- Budżety (K twierdzeń, S spanów) i bariera kolejności (N4) usuwają
-- materiał z wejścia. Gdyby przycięcie było ciche, „model tego nie
-- połączył" byłoby nierozróżnialne od „model tego nie zobaczył". Stąd
-- osobna tabela liczników — nie log, bo pytanie zadaje się na wierszu
-- raportu, tygodnie później.

CREATE TABLE report_run_context (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    report_id         UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,

    -- 'claim' | 'span'. Poziomy NIE mieszają się nigdy (dok. 65 §N1:
    -- przeszła hipoteza nie jest dowodem) — rozdział zaczyna się tutaj,
    -- w zapisie, żeby zapytanie audytowe nie musiało zgadywać.
    item_kind         VARCHAR(16) NOT NULL,
    -- 'window' (F7a, okno deterministyczne) | 'semantic' (F7b, indeks).
    -- Kanał zapisany per element, bo ten sam element może trafić
    -- z obu, a strojenie retrievalu pyta „co dołożyła semantyka".
    channel           VARCHAR(16) NOT NULL DEFAULT 'window',

    source_session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    -- Adres użyty w prompcie: dla spanu 's0821:s07' (data + ref
    -- w obrębie transkrypcji), dla twierdzenia jego UUID. Zapisujemy
    -- ADRES, nie tylko klucz obcy, bo audyt odtwarza to, co model
    -- widział, a model widział adres.
    item_ref          TEXT NOT NULL,
    construct_id      TEXT,

    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (report_id, item_kind, item_ref)
);

CREATE INDEX idx_run_context_report ON report_run_context(report_id);
-- „W ilu raportach wystąpiła ta sesja jako kontekst" — pytanie zadawane
-- przy audycie usunięcia danych i przy analizie wpływu jednej sesji.
CREATE INDEX idx_run_context_source ON report_run_context(source_session_id);

CREATE TABLE report_run_context_stats (
    report_id                   UUID PRIMARY KEY REFERENCES reports(id) ON DELETE CASCADE,

    -- Parametry selekcji obowiązujące w tym przebiegu. Zapisane przy
    -- raporcie, nie tylko w konfiguracji: zmiana W po miesiącu nie może
    -- przepisać historii ani zafałszować benchmarku.
    window_size                 INTEGER NOT NULL DEFAULT 0,
    sessions_loaded             INTEGER NOT NULL DEFAULT 0,
    -- N4: starsze sesje tej kartoteki, które w chwili przebiegu wciąż
    -- się przetwarzały. Pomijamy je i mówimy to wprost — czekanie
    -- groziłoby zakleszczeniem na sesji, która nigdy nie dojdzie.
    sessions_skipped_unfinished INTEGER NOT NULL DEFAULT 0,

    claims_shown                INTEGER NOT NULL DEFAULT 0,
    claims_dropped_budget       INTEGER NOT NULL DEFAULT 0,
    spans_shown                 INTEGER NOT NULL DEFAULT 0,
    spans_dropped_budget        INTEGER NOT NULL DEFAULT 0,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE report_run_context IS
    'Co przebieg zobaczył z poprzednich sesji (dok. 65 §N2). Warunek '
    'twardy dla F7b: bez zapisu wejścia niedeterministyczny retrieval '
    'jest nieaudytowalny.';
COMMENT ON COLUMN report_run_context_stats.sessions_skipped_unfinished IS
    'Starsze sesje kartoteki wciąż przetwarzane w chwili przebiegu. '
    'Pomijane świadomie (nie czekamy — brak zakleszczenia), ale jawnie.';
