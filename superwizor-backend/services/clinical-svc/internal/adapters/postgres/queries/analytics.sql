-- ─────────────────────────────────────────────────────────────────────
-- Zapytania panelu /admin/analytics.
--
-- Trzy konwencje obowiązujące w CAŁYM tym pliku — złamanie którejkolwiek
-- daje liczbę, która wygląda wiarygodnie i jest zła:
--
-- 1. ETYKIETA TYGODNIA to `TO_CHAR(…, 'IYYY-IW')`, nigdy `'YYYY-IW'`.
--    IYYY to rok ISO, YYYY kalendarzowy — te kalendarze rozjeżdżają się
--    na przełomie roku. 28.12.2026 należy do tygodnia ISO 1 roku 2027;
--    maska 'YYYY-IW' dała mu etykietę '2026-01', czyli wsadziła go do
--    słupka ze stycznia 2026. Przy poprawnej masce etykiety sortują się
--    leksykograficznie tak samo jak chronologicznie, więc GROUP BY 1 /
--    ORDER BY 1 po etykiecie jest bezpieczne.
--
-- 2. KUBEŁKOWANIE JEST W `Europe/Warsaw`, nie w UTC. `date_trunc` i
--    `EXTRACT` na wartości timestamptz liczą w strefie sesji bazy, czyli
--    w praktyce w UTC — sesja z poniedziałku 00:30 czasu polskiego wpadała
--    do poprzedniego tygodnia, a wieczorna do złej godziny na heatmapie.
--    Granice wybranego zakresu ($1) zostają instantami i porównują się
--    z timestamptz bez konwersji.
--
-- 3. WSKAŹNIK PROCENTOWY WYCHODZI JAKO 0–100, nie jako ułamek. Frontend
--    rysował ułamek pod etykietą „%", więc awaryjność 2% wyglądała na
--    wykresie jak 0,02% — przy KPI obok, który mnożył przez 100.
--
-- Każde zapytanie, które ma sens w oknie czasowym, przyjmuje sqlc.arg(since)
-- z TimeRangeSelector. Zapytania bez tego parametru (GetWAU,
-- GetPlanDistribution, GetRevenueTrend) są migawkami z definicji i ich
-- kafelki mówią to wprost.
-- ─────────────────────────────────────────────────────────────────────

-- name: GetWAU :one
-- CROSS-SERVICE READ: analytics-only
-- Kroczące 7 dni Z DEFINICJI (Weekly Active Users) — celowo nie reaguje
-- na TimeRangeSelector.
SELECT COUNT(DISTINCT s.therapist_id)::bigint AS count
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.created_at >= NOW() - INTERVAL '7 days'
  AND s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test';

-- name: GetSessionsThisWeek :one
-- CROSS-SERVICE READ: analytics-only
-- „W tym tygodniu" to tydzień KALENDARZOWY od poniedziałku czasu polskiego,
-- zgodnie z opisem kafelka. Poprzednio liczyło kroczące 7 dni.
SELECT COUNT(*)::bigint AS count
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.created_at >= date_trunc('week', NOW() AT TIME ZONE 'Europe/Warsaw')
                         AT TIME ZONE 'Europe/Warsaw'
  AND s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test';

-- name: GetActivationRate :one
-- CROSS-SERVICE READ: analytics-only
SELECT
  COALESCE(
    ROUND(
      100.0 * COUNT(first_session_at) / NULLIF(COUNT(*), 0),
      1
    )::float,
    0.0
  )::float AS rate
FROM v_analytics_activation
WHERE signup_at >= sqlc.arg(since);

-- name: GetOverallSatisfactionRate :one
-- CROSS-SERVICE READ: analytics-only
SELECT
  COALESCE(
    ROUND(
      100.0 * COUNT(*) FILTER (WHERE rr.rating = 'positive') / NULLIF(COUNT(*), 0),
      1
    )::float,
    0.0
  )::float AS rate
FROM report_ratings rr
JOIN users u ON u.id = rr.therapist_id
WHERE u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND rr.created_at >= sqlc.arg(since);

-- name: GetWauTrend :many
-- CROSS-SERVICE READ: analytics-only
-- `week` w widoku to instant lokalnej północy poniedziałku (000102),
-- więc etykietę liczymy z powrotem w Europe/Warsaw.
SELECT
  TO_CHAR(week AT TIME ZONE 'Europe/Warsaw', 'IYYY-IW') AS label,
  active_therapists::float AS value
FROM v_analytics_wau
WHERE week >= sqlc.arg(since)::timestamptz
ORDER BY week ASC;

-- name: GetSessionsTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT
  TO_CHAR(date_trunc('week', s.created_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW') AS label,
  COUNT(*)::float AS value
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetRegistrationsTrend :many
-- CROSS-SERVICE READ: analytics-only
-- Filtr kont wewnętrznych jest tu SZERSZY niż w pozostałych zapytaniach
-- (adresy z '+', @superwizor.ai, konto założyciela). To celowe: liczba
-- rejestracji trafia do mailingu, więc odsiewamy też własne konta robocze.
-- Nie porównuj tej liczby wprost z pierwszym krokiem lejka — mianowniki
-- są różne z założenia.
SELECT
  TO_CHAR(date_trunc('week', created_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW') AS label,
  COUNT(*)::float AS value
FROM users
WHERE role = 'THERAPIST' AND deleted_at IS NULL
  AND email NOT LIKE '%@superwizor.test'
  AND email NOT LIKE '%@example.com'
  AND email NOT LIKE '%@example.test'
  AND email NOT LIKE '%@example.org'
  AND email NOT LIKE '%@test.pl'
  AND email NOT LIKE '%@superwizor.ai'
  AND email NOT LIKE '%+%'
  AND email != 'kolodzmaciej@gmail.com'
  AND created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetRegistrationsDetail :many
-- CROSS-SERVICE READ: analytics-only
-- Kolumny login_count i session_count nie mają własnego okna czasowego i
-- nie potrzebują go: zewnętrzny WHERE zostawia tylko konta założone po
-- `since`, a ani sesja, ani zdarzenie nie może powstać przed założeniem
-- konta. Liczby są więc z definicji z wybranego okresu.
SELECT
  u.id,
  u.email,
  u.first_name,
  u.last_name,
  u.created_at,
  u.has_marketing_consent,
  COALESCE(ae.login_count, 0)::bigint AS login_count,
  COALESCE(s.session_count, 0)::bigint AS session_count
FROM users u
LEFT JOIN (
  SELECT therapist_id, COUNT(*) AS login_count
  FROM analytics_events
  WHERE event_name = 'app.session_started'
  GROUP BY therapist_id
) ae ON ae.therapist_id = u.id
LEFT JOIN (
  SELECT therapist_id, COUNT(*) AS session_count
  FROM sessions
  WHERE deleted_at IS NULL
  GROUP BY therapist_id
) s ON s.therapist_id = u.id
WHERE u.role = 'THERAPIST' AND u.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND u.email NOT LIKE '%@example.org'
  AND u.email NOT LIKE '%@test.pl'
  AND u.email NOT LIKE '%@superwizor.ai'
  AND u.email NOT LIKE '%+%'
  AND u.email != 'kolodzmaciej@gmail.com'
  AND u.created_at >= sqlc.arg(since)
ORDER BY u.created_at DESC;

-- name: GetPlanDistribution :many
-- CROSS-SERVICE READ: analytics-only
-- Migawka „teraz" — rozkład aktywnych subskrypcji nie ma okna czasowego.
SELECT
  sp.display_name AS plan_name,
  COUNT(*)::bigint AS count
FROM subscriptions s
JOIN subscription_plans sp ON s.plan_id = sp.id
WHERE s.status = 'ACTIVE'
GROUP BY 1;

-- name: GetUnitEconomicsKPIs :one
-- CROSS-SERVICE READ: analytics-only
-- Wszystkie trzy liczby z JEDNEGO okna — wybranego zakresu. Poprzednio
-- średnia szła po całej historii, a sumy po zaszytych 30 dniach, więc
-- trzy kafelki w jednym rzędzie opisywały trzy różne przedziały czasu.
SELECT
  -- To samo wyrazenie co linia Σ w GetCostTrend. AVG(total_cost_usd) pomijaloby
  -- wiersze z NULL-em (nieznany stt_model albo niewyceniony model LLM), wiec
  -- kafelek i wykres liczylyby na roznych populacjach.
  COALESCE(AVG(COALESCE(stt_cost_usd, 0) + COALESCE(llm_cost_usd, 0)), 0.0)::float AS avg_cost_per_session,
  COALESCE(SUM(stt_cost_usd), 0.0)::float AS period_stt_cost,
  COALESCE(SUM(llm_cost_usd), 0.0)::float AS period_llm_cost
FROM v_analytics_session_cost
WHERE created_at >= sqlc.arg(since);

-- name: GetAvgTokenUtilization :one
-- CROSS-SERVICE READ: analytics-only
-- Iloraz sum, nie średnia ilorazów: AVG(utilization_pct) dawał tej samej
-- wagi organizacji z limitem 10 tys. tokenów co organizacji z limitem
-- 10 mln. Widok od 000102 zwraca jeden zakres licznika na okres, więc
-- sumy nie liczą tych samych tokenów dwa razy.
SELECT
  COALESCE(
    100.0 * SUM(tokens_used)::float / NULLIF(SUM(tokens_limit), 0),
    0.0
  )::float AS avg_utilization
FROM v_analytics_token_util
-- Okres rozliczeniowy to PRZEDZIAL, nie zdarzenie punktowe. Filtr po samym
-- period_start zostawialby tylko cykle rozpoczete wewnatrz okna — czyli te
-- ledwie rozpoczete, z zuzyciem bliskim zeru — a dla planow rocznych nie
-- zostawialby zadnego. Bierzemy liczniki, ktorych okres NACHODZI na okno.
WHERE period_end >= sqlc.arg(since)
  AND period_start <= now();

-- name: GetCostTrend :many
-- CROSS-SERVICE READ: analytics-only
-- COALESCE na każdym składniku, żeby stos STT+LLM sumował się do linii Σ.
-- Bez tego raport z niewycenialnym modelem (llm_cost_usd IS NULL, celowo —
-- llm-worker nie zapisuje zera) wypadał ze średniej sumy, ale zostawał
-- w średniej STT, i te trzy serie liczyły się na trzech różnych zbiorach.
SELECT
  TO_CHAR(date_trunc('week', created_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW') AS label,
  COALESCE(AVG(COALESCE(stt_cost_usd, 0)), 0.0)::float AS stt_cost,
  COALESCE(AVG(COALESCE(llm_cost_usd, 0)), 0.0)::float AS llm_cost,
  COALESCE(AVG(COALESCE(stt_cost_usd, 0) + COALESCE(llm_cost_usd, 0)), 0.0)::float AS total_cost
FROM v_analytics_session_cost
WHERE created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetTokenUtilizationHeatmap :many
-- CROSS-SERVICE READ: analytics-only
-- Bez LIMIT-u. Poprzedni `ORDER BY 2 ASC LIMIT 50` obcinał NAJNOWSZE
-- tygodnie, więc heatmapa pokazywała wiosnę, gdy panel stał na „7 dni".
SELECT
  o.legal_name::text AS org_name,
  TO_CHAR(v.period_start AT TIME ZONE 'Europe/Warsaw', 'IYYY-IW') AS week,
  COALESCE(
    100.0 * SUM(v.tokens_used)::float / NULLIF(SUM(v.tokens_limit), 0),
    0.0
  )::float AS value
FROM v_analytics_token_util v
JOIN organizations o ON v.organization_id = o.id
-- Nachodzenie okresu na okno, nie jego poczatek — patrz GetAvgTokenUtilization.
WHERE v.period_end >= sqlc.arg(since)
  AND v.period_start <= now()
GROUP BY 1, 2
ORDER BY 2 ASC, 1 ASC;

-- name: GetRevenueTrend :many
-- CROSS-SERVICE READ: analytics-only
-- Migawka MRR per plan, nie trend — nazwa została z czasów, gdy miał nim
-- być. Panel tego nie renderuje; handler traktuje ją fail-soft.
SELECT
  sp.tier::text AS label,
  COUNT(*)::float AS solo_revenue,
  COALESCE(SUM(sp.price_gross), 0)::float AS pro_revenue,
  COALESCE(SUM(sp.price_gross), 0)::float AS total_revenue
FROM subscriptions s
JOIN subscription_plans sp ON s.plan_id = sp.id
WHERE s.status = 'ACTIVE'
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetTokenUsageTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT
  TO_CHAR(date_trunc('week', created_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW') AS label,
  COALESCE(SUM(llm_input_tokens), 0)::bigint AS input_tokens,
  COALESCE(SUM(llm_output_tokens), 0)::bigint AS output_tokens
FROM v_analytics_session_cost
WHERE created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetAIQualityKPIs :one
-- CROSS-SERVICE READ: analytics-only
-- Podzapytanie dla latencji, żeby JOIN 1:N nie mnożył wierszy sesji.
-- Mianownik awaryjności to sesje w stanie KOŃCOWYM: COMPLETED + FAILED.
-- Sesja w trakcie przetwarzania nie jest jeszcze ani sukcesem, ani porażką,
-- a CANCELED to decyzja użytkownika, nie awaria systemu — trzymanie ich
-- w mianowniku zaniżało wskaźnik tym bardziej, im więcej było ruchu.
-- Wynik w procentach (0–100).
SELECT
  COALESCE((
    SELECT AVG(e2e_seconds)
    FROM v_analytics_pipeline_latency
    WHERE session_at >= sqlc.arg(since)
  ), 0.0)::float AS avg_pipeline_latency,
  COALESCE(
    (100.0 * COUNT(*) FILTER (WHERE s.status = 'FAILED')::float
     / NULLIF(COUNT(*) FILTER (WHERE s.status IN ('COMPLETED', 'FAILED')), 0)),
    0.0
  )::float AS failure_rate_7d
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= sqlc.arg(since);

-- name: GetRelabelRate :one
-- CROSS-SERVICE READ: analytics-only
-- Wynik w procentach (0–100). Dochodzi filtr kont testowych — bez niego
-- wskaźnik liczył sesje z przebiegów E2E, które etykiet nie poprawiają.
-- NOT EXISTS zamiast JOIN, bo analytics_events.therapist_id jest opcjonalne
-- (zdarzenia systemowe) — INNER JOIN wyciąłby je z mianownika.
SELECT
  COALESCE(
    (100.0 * COUNT(DISTINCT ae.session_id) FILTER (WHERE ae.event_name = 'speaker_labels.updated')::float
     / NULLIF(COUNT(DISTINCT ae.session_id) FILTER (WHERE ae.event_name = 'upload.finalized'), 0)),
    0.0
  )::float AS relabel_rate
FROM analytics_events ae
WHERE NOT EXISTS (
    SELECT 1 FROM users u
    WHERE u.id = ae.therapist_id
      AND (u.email LIKE '%@superwizor.test'
        OR u.email LIKE '%@example.com'
        OR u.email LIKE '%@example.test')
  )
  AND ae.occurred_at >= sqlc.arg(since);

-- name: GetSatisfactionTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT
  TO_CHAR(week AT TIME ZONE 'Europe/Warsaw', 'IYYY-IW') AS label,
  satisfaction_pct::float AS satisfaction_pct
FROM v_analytics_satisfaction
WHERE week >= sqlc.arg(since)::timestamptz
ORDER BY week ASC;

-- name: GetIssueCategories :many
-- CROSS-SERVICE READ: analytics-only
SELECT
  issue::text AS category,
  COUNT(*)::bigint AS count
FROM report_ratings rr
JOIN users u ON u.id = rr.therapist_id,
LATERAL UNNEST(rr.issues) AS issue
WHERE u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND rr.created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 2 DESC;

-- name: GetLatencyTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT
  TO_CHAR(date_trunc('week', session_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW') AS label,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e2e_seconds)::float AS p50,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY e2e_seconds)::float AS p95
FROM v_analytics_pipeline_latency
WHERE session_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetFailureRateTrend :many
-- CROSS-SERVICE READ: analytics-only
-- Wynik w procentach (0–100); mianownik jak w GetAIQualityKPIs — tylko
-- stany końcowe. `total` też liczy stany końcowe, żeby tooltip zgadzał się
-- z wykresem.
SELECT
  TO_CHAR(date_trunc('week', s.created_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW') AS label,
  COALESCE(
    (100.0 * COUNT(*) FILTER (WHERE s.status = 'FAILED')::float
     / NULLIF(COUNT(*) FILTER (WHERE s.status IN ('COMPLETED', 'FAILED')), 0)),
    0.0
  )::float AS failure_rate,
  COUNT(*) FILTER (WHERE s.status IN ('COMPLETED', 'FAILED'))::bigint AS total,
  COUNT(*) FILTER (WHERE s.status = 'FAILED')::bigint AS failed
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetFunnelSteps :one
-- CROSS-SERVICE READ: analytics-only
-- Krok „przeczytanie raportu" liczony TU, a nie osobnym zapytaniem po
-- gołej tabeli zdarzeń. Poprzednio pochodził z innej populacji (bez filtra
-- kont testowych, bez sprawdzenia roli, bez okna czasowego), więc lejek
-- potrafił się rozszerzać zamiast zwężać.
SELECT
  COUNT(*)::bigint AS signup_count,
  COUNT(a.first_patient_at)::bigint AS patient_created_count,
  COUNT(a.first_session_at)::bigint AS session_completed_count,
  -- Warunek `first_session_at IS NOT NULL` jest tu konieczny, nie ozdobny:
  -- bez niego EXISTS wiaze sie wylacznie z therapist_id i terapeuta, ktory
  -- otworzyl raport, ale nie ma ukonczonej sesji, rozszerzalby lejek.
  COUNT(*) FILTER (
      WHERE a.first_session_at IS NOT NULL
        AND EXISTS (
          SELECT 1 FROM analytics_events ae
          WHERE ae.therapist_id = a.therapist_id
            AND ae.event_name = 'report.read_started'
        )
  )::bigint AS report_read_count,
  COUNT(a.first_rating_at)::bigint AS rated_count
FROM v_analytics_activation a
WHERE a.signup_at >= sqlc.arg(since);

-- name: GetCohortRetention :many
-- CROSS-SERVICE READ: analytics-only
-- Bez LIMIT-u (poprzedni `LIMIT 200` obcinał NAJNOWSZE kohorty, bo sortowanie
-- rosło od najstarszej). Zakres tnie po dacie rejestracji, więc macierz jest
-- ograniczona kohortami z wybranego okresu, a nie przypadkowym progiem.
-- `pct` w procentach (0–100); `cohort_size` wyjeżdża po to, żeby KPI retencji
-- mogło ważyć kohorty ich liczebnością zamiast uśredniać ilorazy.
WITH cohort_sizes AS (
  SELECT
    date_trunc('week', signup_at AT TIME ZONE 'Europe/Warsaw') AS cohort_week,
    COUNT(DISTINCT therapist_id)::float AS total_size
  FROM v_analytics_activation
  WHERE signup_at >= sqlc.arg(since)::timestamptz
  GROUP BY 1
),
activity AS (
  SELECT
    s.therapist_id,
    date_trunc('week', s.created_at AT TIME ZONE 'Europe/Warsaw') AS activity_week
  FROM sessions s
  WHERE s.deleted_at IS NULL
),
cohort_activity AS (
  SELECT
    date_trunc('week', u.signup_at AT TIME ZONE 'Europe/Warsaw') AS cohort_week,
    a.activity_week,
    COUNT(DISTINCT u.therapist_id)::float AS active_size
  FROM v_analytics_activation u
  JOIN activity a ON u.therapist_id = a.therapist_id
  WHERE u.signup_at >= sqlc.arg(since)::timestamptz
    AND a.activity_week >= date_trunc('week', u.signup_at AT TIME ZONE 'Europe/Warsaw')
  GROUP BY 1, 2
)
SELECT
  TO_CHAR(cs.cohort_week, 'IYYY-IW')::text AS cohort,
  TO_CHAR(ca.activity_week, 'IYYY-IW')::text AS week,
  COALESCE(100.0 * ca.active_size / NULLIF(cs.total_size, 0), 0.0)::float AS pct
FROM cohort_sizes cs
JOIN cohort_activity ca ON cs.cohort_week = ca.cohort_week
ORDER BY 1 ASC, 2 ASC;

-- name: GetRetentionCohorts :many
-- CROSS-SERVICE READ: analytics-only
-- Wejscie dla KPI „Retencja 30-dniowa". Osobne zapytanie od macierzy powyzej,
-- bo ten wskaznik z definicji patrzy cztery tygodnie wstecz. Gdyby dzielil
-- okno z TimeRangeSelectorem, przy zakresie „7 dni" ani jedna kohorta nie
-- bylaby jeszcze dojrzala i kafelek pokazywalby 0% — liczbe wygladajaca
-- wiarygodnie i falszywa. Okno jest wiec stale, tak jak w GetWAU.
--
-- LEFT JOIN, nie INNER: kohorta, z ktorej NIKT nigdy nie nagral sesji, ma
-- wrocic z pustym `week` i zerowym `pct`, zeby wejsc do MIANOWNIKA KPI.
-- Przy INNER JOIN znikala z rachunku i zawyzala wynik.
WITH cohort_sizes AS (
  SELECT
    date_trunc('week', signup_at AT TIME ZONE 'Europe/Warsaw') AS cohort_week,
    COUNT(DISTINCT therapist_id)::float AS total_size
  FROM v_analytics_activation
  WHERE signup_at >= now() - INTERVAL '26 weeks'
  GROUP BY 1
),
activity AS (
  SELECT
    s.therapist_id,
    date_trunc('week', s.created_at AT TIME ZONE 'Europe/Warsaw') AS activity_week
  FROM sessions s
  WHERE s.deleted_at IS NULL
),
cohort_activity AS (
  SELECT
    date_trunc('week', u.signup_at AT TIME ZONE 'Europe/Warsaw') AS cohort_week,
    a.activity_week,
    COUNT(DISTINCT u.therapist_id)::float AS active_size
  FROM v_analytics_activation u
  JOIN activity a ON u.therapist_id = a.therapist_id
  WHERE u.signup_at >= now() - INTERVAL '26 weeks'
    AND a.activity_week >= date_trunc('week', u.signup_at AT TIME ZONE 'Europe/Warsaw')
  GROUP BY 1, 2
)
SELECT
  TO_CHAR(cs.cohort_week, 'IYYY-IW')::text AS cohort,
  COALESCE(TO_CHAR(ca.activity_week, 'IYYY-IW'), '')::text AS week,
  COALESCE(100.0 * ca.active_size / NULLIF(cs.total_size, 0), 0.0)::float AS pct,
  cs.total_size::bigint AS cohort_size
FROM cohort_sizes cs
LEFT JOIN cohort_activity ca ON cs.cohort_week = ca.cohort_week
ORDER BY 1 ASC, 2 ASC;

-- name: GetActivationTimeHistogram :many
-- CROSS-SERVICE READ: analytics-only
-- ORDER BY po najmniejszej liczbie godzin w kubełku — kubełki są rozłącznymi
-- przedziałami, więc to je porządkuje chronologicznie. Bez tego kolejność
-- słupków na osi X zależała od planu wykonania.
SELECT
  CASE
    WHEN hours_to_first_session <= 1 THEN '0-1h'
    WHEN hours_to_first_session <= 24 THEN '1-24h'
    WHEN hours_to_first_session <= 72 THEN '24-72h'
    ELSE '72h+'
  END AS bucket_label,
  COUNT(*)::bigint AS count
FROM v_analytics_activation
WHERE hours_to_first_session IS NOT NULL
  AND signup_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY MIN(hours_to_first_session) ASC;

-- name: GetHourlyHeatmap :many
-- CROSS-SERVICE READ: analytics-only
-- DOW i HOUR w Europe/Warsaw. W UTC sesja o 21:30 czasu polskiego trafiała
-- latem do kubełka 19:00, a sesja z poniedziałku 00:30 — do niedzieli.
-- DOW 0 = niedziela, zgodnie z mapowaniem nazw dni na froncie.
SELECT
  EXTRACT(DOW FROM s.created_at AT TIME ZONE 'Europe/Warsaw')::int AS day_of_week,
  EXTRACT(HOUR FROM s.created_at AT TIME ZONE 'Europe/Warsaw')::int AS hour,
  COUNT(*)::bigint AS count
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= sqlc.arg(since)
GROUP BY 1, 2
ORDER BY 1 ASC, 2 ASC;

-- name: GetUploadFailuresTrend :many
-- CROSS-SERVICE READ: analytics-only
-- Mianownik to SAME próby wgrania. Poprzednio było COUNT(*) po zbiorze
-- {upload.initiated, upload.failed}, a te zdarzenia nie są rozłączne —
-- jedno nieudane wgranie emituje oba, więc wskaźnik wychodził
-- failed/(initiated+failed) i systematycznie zaniżał awaryjność.
-- Wynik w procentach (0–100).
SELECT
  TO_CHAR(date_trunc('week', occurred_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW') AS label,
  COALESCE(
    (100.0 * COUNT(*) FILTER (WHERE event_name = 'upload.failed')::float
     / NULLIF(COUNT(*) FILTER (WHERE event_name = 'upload.initiated'), 0)),
    0.0
  )::float AS failure_rate,
  COUNT(*) FILTER (WHERE event_name = 'upload.initiated')::bigint AS total,
  COUNT(*) FILTER (WHERE event_name = 'upload.failed')::bigint AS failed
FROM analytics_events
WHERE event_name IN ('upload.initiated', 'upload.failed')
  AND occurred_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetModalityDistribution :many
-- CROSS-SERVICE READ: analytics-only
SELECT
  m.display_name::text AS modality_name,
  COUNT(s.id)::bigint AS count
FROM sessions s
JOIN patient_files pf ON s.patient_file_id = pf.id
JOIN modalities m ON pf.modality_id = m.id
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND pf.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 2 DESC;

-- name: GetAvgSessionDuration :one
-- CROSS-SERVICE READ: analytics-only
SELECT
  COALESCE(AVG(s.duration_seconds), 0.0)::float AS avg_duration
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= sqlc.arg(since);

-- name: GetSessionDurationTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT
  TO_CHAR(date_trunc('week', s.created_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW') AS label,
  COALESCE(AVG(s.duration_seconds), 0.0)::float AS value
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetRatingsKPIs :one
-- CROSS-SERVICE READ: analytics-only
-- Liczniki ocen do kafelków zakładki „Feedback raportów".
SELECT
  COUNT(*)::bigint AS total,
  COUNT(*) FILTER (WHERE rr.rating = 'positive')::bigint AS positive,
  COUNT(*) FILTER (WHERE rr.rating = 'negative')::bigint AS negative,
  COUNT(*) FILTER (WHERE rr.notes != '')::bigint AS with_notes
FROM report_ratings rr
JOIN users u ON u.id = rr.therapist_id
WHERE u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND rr.created_at >= sqlc.arg(since);

-- ─────────────────────────────────────────────────────────────────
-- Użycie i pętla z klientem (14.08.2026).
--
-- Panel odpowiadał dotąd na pytanie "jak działa system" — koszty,
-- jakość modeli, awarie. Nie odpowiadał na "jak ludzie z niego
-- korzystają". Poniższe zapytania nie wymagają ANI JEDNEGO nowego
-- zdarzenia: wszystko leży już w sessions, invitations i w parach
-- report.read_started / report.read_finished.
-- ─────────────────────────────────────────────────────────────────

-- name: GetClientSharingTrend :many
-- Ile ukończonych sesji trafia do klienta i ile z nich klient ukrywa.
-- client_hidden_at to sygnał odrzucenia — raport dotarł, ale klient go
-- schował; bez tego widzielibyśmy tylko wysyłkę, nie odbiór.
--
-- Etykieta jak wszędzie indziej ('IYYY-IW'). Wcześniej było 'MM-DD' bez
-- roku, więc styczeń sortował się przed grudniem, a dwa tygodnie z różnych
-- lat mogły się skleić. Okno bierze się z zakresu, nie z zaszytych 12 tygodni.
SELECT to_char(date_trunc('week', s.created_at AT TIME ZONE 'Europe/Warsaw'), 'IYYY-IW')::text AS label,
       count(*)::int AS sessions_total,
       count(*) FILTER (WHERE s.shared_with_client_at IS NOT NULL)::int AS shared,
       count(*) FILTER (WHERE s.client_hidden_at IS NOT NULL)::int AS hidden
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND s.status = 'COMPLETED'
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1;

-- name: GetClientInvitationFunnel :one
-- Lejek zaproszeń do aplikacji klienta. patient_file_id odróżnia
-- zaproszenie klienta od zaproszenia terapeuty do organizacji.
SELECT count(*)::int AS sent,
       count(*) FILTER (WHERE accepted_at IS NOT NULL)::int AS accepted,
       count(*) FILTER (WHERE revoked_at IS NOT NULL)::int AS revoked,
       count(*) FILTER (WHERE accepted_at IS NULL
                          AND revoked_at IS NULL
                          AND expires_at < now())::int AS expired,
       COALESCE(percentile_cont(0.5) WITHIN GROUP (
           ORDER BY EXTRACT(EPOCH FROM (accepted_at - created_at)) / 3600.0
         ) FILTER (WHERE accepted_at IS NOT NULL), 0)::float AS median_hours_to_accept
FROM invitations
WHERE patient_file_id IS NOT NULL
  AND created_at >= sqlc.arg(since);

-- name: GetPairingCodeFriction :many
-- Ile prób kodu parowania potrzebuje klient. Rozkład, nie średnia —
-- interesuje nas ogon, czyli ci, którzy męczą się kilka razy.
SELECT COALESCE(code_attempts, 0)::int AS attempts,
       count(*)::int AS invitations
FROM invitations
WHERE patient_file_id IS NOT NULL
  AND pairing_code_hash IS NOT NULL
  AND created_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 1;

-- name: GetReportReadingStats :one
-- Czas czytania raportu. active_read_ms mierzy klient i zatrzymuje
-- licznik przy zejściu aplikacji w tło, więc to czas AKTYWNY, a nie
-- czas otwartego ekranu.
--
-- Różnica started-finished to czytania przerwane. Może wyjść ujemna na
-- granicy okna (domknięcie czytania rozpoczętego przed `since`), dlatego
-- kafelek na froncie klamruje ją do zera.
SELECT count(*) FILTER (WHERE event_name = 'report.read_started')::int AS started,
       count(*) FILTER (WHERE event_name = 'report.read_finished')::int AS finished,
       COALESCE(percentile_cont(0.5) WITHIN GROUP (
           ORDER BY (properties->>'active_read_ms')::numeric / 1000.0
         ) FILTER (WHERE properties->>'active_read_ms' IS NOT NULL), 0)::float AS median_seconds,
       COALESCE(percentile_cont(0.9) WITHIN GROUP (
           ORDER BY (properties->>'active_read_ms')::numeric / 1000.0
         ) FILTER (WHERE properties->>'active_read_ms' IS NOT NULL), 0)::float AS p90_seconds
FROM analytics_events
WHERE event_name IN ('report.read_started', 'report.read_finished')
  AND occurred_at >= sqlc.arg(since);

-- name: GetReadingPlatformSplit :many
-- Gdzie czytane są raporty. client_platform jest wypełniany przy
-- każdym zdarzeniu klienckim, więc to działa od pierwszego dnia.
SELECT COALESCE(NULLIF(client_platform, ''), 'unknown')::text AS platform,
       count(*)::int AS reads
FROM analytics_events
WHERE event_name = 'report.read_started'
  AND occurred_at >= sqlc.arg(since)
GROUP BY 1
ORDER BY 2 DESC;
