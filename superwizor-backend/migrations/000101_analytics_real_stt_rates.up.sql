-- 000101: Analityka — realna stawka STT i koniec podwójnego liczenia sesji.
--
-- Widok v_analytics_session_cost (000044, przebudowany o filtr danych
-- testowych w 000045) mylił się na dwa niezależne sposoby, oba zawyżając
-- koszt pokazywany w /admin/analytics → „Koszty i Ekonomika".
--
-- 1. STAWKA. Koszt STT był zaszyty jako 0,016 USD/min z komentarzem
--    „Chirp 3 HD". To cennik Google STT V2 w trybie *standard batch*, a
--    produkcja nigdy tak nie chodziła: stt-worker wysyła BatchRecognize
--    z ProcessingStrategy=DYNAMIC_BATCHING (stt-worker/main.go,
--    processingStrategy()), czyli 0,003 USD/min. Potem doszedł Deepgram
--    nova-3, a od 2026-07-31 (docs/59) produkcja stoi na ElevenLabs
--    Scribe v2. Panel zawyżał więc STT ~4,4× w erze ElevenLabs i ~5,3×
--    w erze Chirpa.
--
-- 2. KROTNOŚĆ. Widok szedł FROM reports, a reports NIE ma UNIQUE na
--    session_id — regeneracja raportu (parent_report_id,
--    generation_count) dokłada kolejny wiersz. Każdy z nich niósł PEŁNY
--    koszt transkrypcji sesji, więc sesja przetworzona dwa razy płaciła
--    za STT dwa razy. Transkrypcja jest jedna na sesję
--    (UNIQUE transcripts(session_id), migracja 000021), więc teraz
--    liczy się raz; koszt i tokeny LLM sumują się po wszystkich
--    generacjach, bo każda naprawdę kosztowała.
--
-- Stawkę wiążemy z modelem zapisanym w transcripts.stt_model, nie z
-- „aktualnym dostawcą". Wiersze z ery Chirpa mają być wycenione po
-- Chirpie — to ta sama zasada, którą pkg/llmcost stosuje do modeli LLM
-- (stawka należy do tego, co naprawdę policzyło dany wiersz, inaczej
-- historia zmienia się przy każdej migracji dostawcy).
--
-- Cenniki sprawdzone 2026-08-28:
--   elevenlabs-scribe-v2  0,22 USD/h  = 0,00366667 USD/min
--                         Stawka bazowa: elevenlabs_path.go woła
--                         Transcribe z samym Language, bez keyterm
--                         prompting (+0,05/h) i entity detection
--                         (+0,07/h), więc dopłaty nie obowiązują.
--   deepgram-nova-3       0,0092 USD/min   (nova-3 multilingual — polski)
--   chirp_3               0,003  USD/min   (dynamic batch recognition)
--
-- Nieznany model daje NULL, nie zero i nie stawkę „na oko": zero
-- cichutko zaniżyłoby dashboard, a podstawienie stawki bieżącego
-- dostawcy ukryłoby fakt, że ktoś dodał providera i nie ruszył tego
-- widoku. Kolumna stt_model jest wystawiona właśnie po to, żeby dało się
-- to wykryć jednym zapytaniem:
--   SELECT DISTINCT stt_model FROM v_analytics_session_cost
--   WHERE stt_cost_usd IS NULL;

DROP VIEW IF EXISTS v_analytics_session_cost CASCADE;

CREATE VIEW v_analytics_session_cost AS
WITH stt AS (
    -- 1:1 z sesją dzięki UNIQUE transcripts(session_id) (000021).
    SELECT t.session_id,
           t.stt_model,
           CASE t.stt_model
               WHEN 'elevenlabs-scribe-v2' THEN 0.22 / 60.0
               WHEN 'deepgram-nova-3'      THEN 0.0092
               WHEN 'chirp_3'              THEN 0.003
               ELSE NULL
           END AS usd_per_min
    FROM transcripts t
),
llm AS (
    -- Jeden wiersz na sesję. SUM pomija NULL-e, więc sesja, w której
    -- jedna generacja miała niewycenialny model (llm_total_cost_usd IS
    -- NULL), a druga nie, pokazuje koszt tej wycenialnej. NULL zostaje
    -- tylko wtedy, gdy żadna generacja nie dała się wycenić.
    SELECT r.session_id,
           SUM(r.llm_input_tokens)::bigint  AS llm_input_tokens,
           SUM(r.llm_output_tokens)::bigint AS llm_output_tokens,
           SUM(r.llm_total_cost_usd)        AS llm_cost_usd,
           COUNT(*)::int                    AS report_count
    FROM reports r
    GROUP BY r.session_id
)
SELECT s.id                AS session_id,
       s.therapist_id,
       u.organization_id,
       s.duration_seconds,
       llm.llm_input_tokens,
       llm.llm_output_tokens,
       llm.llm_cost_usd,
       llm.report_count,
       stt.stt_model,
       ROUND((s.duration_seconds / 60.0) * stt.usd_per_min, 6) AS stt_cost_usd,
       ROUND(llm.llm_cost_usd + (s.duration_seconds / 60.0) * stt.usd_per_min, 6)
                           AS total_cost_usd,
       s.created_at
FROM sessions s
-- INNER JOIN na llm zachowuje populację starego widoku: liczymy sesje,
-- które doszły do raportu. LEFT JOIN na stt, bo brak transkryptu ma dać
-- NULL w koszcie STT, a nie wyciąć sesję z rachunku LLM.
JOIN llm       ON llm.session_id = s.id
LEFT JOIN stt  ON stt.session_id = s.id
JOIN users u   ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test';

COMMENT ON VIEW v_analytics_session_cost IS
    'Koszt jednostkowy sesji: jeden wiersz na sesję, która doczekała się '
    'raportu. STT wyceniane po transcripts.stt_model (migracja 000101), '
    'LLM sumowane po wszystkich generacjach raportu. Dodając dostawcę STT '
    'trzeba dopisać jego stawkę do CASE w tym widoku — inaczej stt_cost_usd '
    'wyjdzie NULL.';
