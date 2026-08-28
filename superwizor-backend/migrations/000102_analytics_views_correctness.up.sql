-- 000102: Analityka — strefa czasowa, krotność wierszy i zakres liczników.
--
-- Trzy widoki z 000044/000045 liczyły źle. Każdy z innego powodu, każdy
-- widoczny w panelu /admin/analytics.
--
-- 1. STREFA CZASOWA. v_analytics_wau i v_analytics_satisfaction kubełkują
--    date_trunc('week', ts) na wartości timestamptz, co Postgres liczy w
--    strefie sesji — w praktyce UTC. Użytkownicy są w Polsce, więc sesja
--    z poniedziałku 00:30 czasu lokalnego wpadała do POPRZEDNIEGO tygodnia.
--    Kolumna `week` jest teraz instantem lokalnej północy poniedziałku,
--    dalej typu timestamptz — dzięki temu WHERE week >= $1 w zapytaniach
--    nadal porównuje instanty, a nie gołe daty.
--
-- 2. KROTNOŚĆ. v_analytics_pipeline_latency robił JOIN reports bez
--    agregacji, a reports nie ma UNIQUE(session_id) (regeneracje raportu —
--    parent_report_id, generation_count). Sesja z trzema raportami wchodziła
--    do mediany i p95 trzykrotnie, przeważając rozkład w stronę sesji, które
--    z jakiegoś powodu trzeba było przeliczać. Teraz jeden wiersz na sesję,
--    a „opóźnienie potoku" to czas do PIERWSZEGO raportu — bo to jest ta
--    liczba, na którą czeka terapeuta.
--
-- 3. ZAKRES LICZNIKÓW. v_analytics_token_util powstał, gdy jedna subskrypcja
--    miała jeden licznik. Migracja 000064 dodała usage_counters.therapist_id
--    i od tej pory subskrypcja ma licznik org-level (therapist_id IS NULL)
--    ORAZ po jednym na terapeutę. Widok zwracał wszystkie naraz, więc panel
--    uśredniał ilorazy o dwóch różnych mianownikach.
--
--    Pierwszeństwo ma licznik ORG-LEVEL, a nie — jak w ReserveCredit —
--    per-terapeuta. To celowa różnica: ReserveCredit pyta „czy TEN terapeuta
--    ma jeszcze kredyt", a panel pyta „ile ze swojego limitu zużyła
--    organizacja". Liczniki seatowe są mintowane leniwie (przy pierwszym
--    zużyciu), więc ich SUM(tokens_limit) to nie limit organizacji, tylko
--    limit foteli, które akurat zdążyły się obudzić — mianownik rosnący
--    w trakcie okresu i systematycznie zawyżający utylizację. Licznik
--    org-level niesie pełny przydział od pierwszego dnia cyklu. Wiersze
--    seatowe wchodzą tylko wtedy, gdy org-level dla danego okresu nie
--    istnieje (subskrypcje sprzed 000064 albo czysto seatowe).
--
--    Przy okazji widok dostaje filtr kont testowych. Komentarz w 000045
--    („nie wymaga filtra — operuje na subskrypcjach/org, nie na email")
--    był błędny: organizacje zakładane przez testy E2E mają subskrypcje i
--    liczniki jak każde inne, więc „E2E Therapist Org" stało w panelu obok
--    prawdziwych klientów. Filtrujemy po tym, czy organizacja ma choć
--    jednego nietestowego użytkownika.

-- ── V1: WAU — tygodnie w Europe/Warsaw ────────────────────────────────
DROP VIEW IF EXISTS v_analytics_wau CASCADE;
CREATE VIEW v_analytics_wau AS
SELECT date_trunc('week', s.created_at AT TIME ZONE 'Europe/Warsaw')
           AT TIME ZONE 'Europe/Warsaw' AS week,
       COUNT(DISTINCT s.therapist_id) AS active_therapists
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
GROUP BY 1;

-- ── V2: Częstotliwość sesji — tygodnie w Europe/Warsaw ────────────────
DROP VIEW IF EXISTS v_analytics_session_freq CASCADE;
CREATE VIEW v_analytics_session_freq AS
SELECT s.therapist_id,
       date_trunc('week', s.created_at AT TIME ZONE 'Europe/Warsaw')
           AT TIME ZONE 'Europe/Warsaw' AS week,
       COUNT(*) AS session_count,
       AVG(s.duration_seconds) AS avg_duration_s,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY s.duration_seconds) AS median_duration_s
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
GROUP BY 1, 2;

-- ── V3: Opóźnienie potoku — jeden wiersz na sesję ─────────────────────
DROP VIEW IF EXISTS v_analytics_pipeline_latency CASCADE;
CREATE VIEW v_analytics_pipeline_latency AS
SELECT s.id           AS session_id,
       s.therapist_id,
       EXTRACT(EPOCH FROM (r.created_at - s.created_at)) AS e2e_seconds,
       t.stt_processing_seconds,
       r.llm_processing_seconds,
       s.created_at   AS session_at
FROM sessions s
JOIN users u ON u.id = s.therapist_id
-- transcripts(session_id) jest UNIQUE od 000021, więc ten JOIN nie mnoży.
JOIN transcripts t ON t.session_id = s.id
-- reports NIE jest unikalne per sesja — bierzemy pierwszy raport, bo to on
-- kończy oczekiwanie terapeuty. LATERAL zamiast JOIN, żeby zostać przy
-- jednym wierszu na sesję bez GROUP BY po całej reszcie kolumn.
JOIN LATERAL (
    SELECT rr.created_at, rr.llm_processing_seconds
    FROM reports rr
    WHERE rr.session_id = s.id
    ORDER BY rr.created_at ASC
    LIMIT 1
) r ON TRUE
WHERE s.status = 'COMPLETED'
  AND s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test';

-- ── V5: Satysfakcja — tygodnie w Europe/Warsaw ────────────────────────
DROP VIEW IF EXISTS v_analytics_satisfaction CASCADE;
CREATE VIEW v_analytics_satisfaction AS
SELECT date_trunc('week', rr.created_at AT TIME ZONE 'Europe/Warsaw')
           AT TIME ZONE 'Europe/Warsaw' AS week,
       COUNT(*) AS total_ratings,
       COUNT(*) FILTER (WHERE rr.rating = 'positive') AS positive,
       COUNT(*) FILTER (WHERE rr.rating = 'negative') AS negative,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rr.rating = 'positive')
             / NULLIF(COUNT(*), 0), 1) AS satisfaction_pct
FROM report_ratings rr
JOIN users u ON u.id = rr.therapist_id
WHERE u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
GROUP BY 1;

-- ── V7: Utylizacja tokenów — jeden zakres, bez kont testowych ─────────
DROP VIEW IF EXISTS v_analytics_token_util CASCADE;
CREATE VIEW v_analytics_token_util AS
WITH scoped AS (
    SELECT uc.subscription_id,
           uc.therapist_id,
           uc.period_start,
           uc.period_end,
           uc.tokens_limit,
           uc.tokens_used,
           sub.organization_id,
           -- Czy dla tej subskrypcji i tego okresu istnieje licznik org-level.
           -- Jeśli tak, to on niesie pełny przydział i tylko jego bierzemy —
           -- dodanie do niego liczników seatowych policzyłoby te same tokeny
           -- dwa razy.
           bool_or(uc.therapist_id IS NULL) OVER (
               PARTITION BY uc.subscription_id, uc.period_start
           ) AS has_org_counter
    FROM usage_counters uc
    JOIN subscriptions sub ON sub.id = uc.subscription_id
)
SELECT s.subscription_id,
       s.organization_id,
       s.therapist_id,
       CASE WHEN s.therapist_id IS NULL THEN 'org' ELSE 'therapist' END::text AS scope,
       s.period_start,
       s.period_end,
       s.tokens_limit,
       s.tokens_used,
       ROUND(100.0 * s.tokens_used / NULLIF(s.tokens_limit, 0), 1) AS utilization_pct
FROM scoped s
WHERE ((s.has_org_counter AND s.therapist_id IS NULL)
    OR (NOT s.has_org_counter AND s.therapist_id IS NOT NULL))
  AND EXISTS (
        SELECT 1
        FROM users u
        WHERE u.organization_id = s.organization_id
          AND u.deleted_at IS NULL
          AND u.email NOT LIKE '%@superwizor.test'
          AND u.email NOT LIKE '%@example.com'
          AND u.email NOT LIKE '%@example.test'
  );

COMMENT ON VIEW v_analytics_token_util IS
    'Liczniki zużycia tokenów sprowadzone do JEDNEGO zakresu na (subskrypcja, '
    'okres): org-level gdy istnieje, per-terapeuta w przeciwnym razie '
    '(migracja 000102). Odwrotnie niż w ReserveCredit — panel mierzy zużycie '
    'ORGANIZACJI, a liczniki seatowe są mintowane leniwie, więc ich suma '
    'limitów nie jest limitem organizacji. '
    'utilization_pct jest ilorazem POJEDYNCZEGO wiersza — agregując po '
    'organizacji licz SUM(tokens_used)/SUM(tokens_limit), nie AVG(utilization_pct).';
