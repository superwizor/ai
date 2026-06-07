-- Migracja: Filtracja danych testowych z widoków analitycznych
-- Dane @superwizor.test i @example.com to seed z CI/E2E testów, nie prawdziwi użytkownicy.

-- Kluczowe widoki do przebudowy: v_analytics_activation, v_analytics_wau, v_analytics_session_freq

-- V1: WAU (filtr na test emails przez JOIN z users)
DROP VIEW IF EXISTS v_analytics_wau CASCADE;
CREATE VIEW v_analytics_wau AS
SELECT date_trunc('week', s.created_at) AS week,
       COUNT(DISTINCT s.therapist_id) AS active_therapists
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
GROUP BY 1;

-- V2: Częstotliwość sesji na terapeutę (filtr)
DROP VIEW IF EXISTS v_analytics_session_freq CASCADE;
CREATE VIEW v_analytics_session_freq AS
SELECT s.therapist_id,
       date_trunc('week', s.created_at) AS week,
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

-- V3: Pipeline latency (filtr)
DROP VIEW IF EXISTS v_analytics_pipeline_latency CASCADE;
CREATE VIEW v_analytics_pipeline_latency AS
SELECT s.id AS session_id,
       s.therapist_id,
       EXTRACT(EPOCH FROM (r.created_at - s.created_at)) AS e2e_seconds,
       t.stt_processing_seconds,
       r.llm_processing_seconds,
       s.created_at AS session_at
FROM sessions s
JOIN users u ON u.id = s.therapist_id
JOIN transcripts t ON t.session_id = s.id
JOIN reports r ON r.session_id = s.id
WHERE s.status = 'COMPLETED' AND s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test';

-- V4: Koszt sesji (filtr)
DROP VIEW IF EXISTS v_analytics_session_cost CASCADE;
CREATE VIEW v_analytics_session_cost AS
SELECT r.session_id,
       s.therapist_id,
       u.organization_id,
       s.duration_seconds,
       r.llm_input_tokens,
       r.llm_output_tokens,
       r.llm_total_cost_usd AS llm_cost_usd,
       ROUND((s.duration_seconds / 60.0) * 0.016, 6) AS stt_cost_usd,
       ROUND(r.llm_total_cost_usd + (s.duration_seconds / 60.0) * 0.016, 6) AS total_cost_usd,
       s.created_at
FROM reports r
JOIN sessions s ON s.id = r.session_id
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test';

-- V5: Satysfakcja (filtr przez therapist)
DROP VIEW IF EXISTS v_analytics_satisfaction CASCADE;
CREATE VIEW v_analytics_satisfaction AS
SELECT date_trunc('week', rr.created_at) AS week,
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

-- V6: Lejek aktywacyjny (filtr na test emails)
DROP VIEW IF EXISTS v_analytics_activation CASCADE;
CREATE VIEW v_analytics_activation AS
SELECT u.id AS therapist_id,
       u.created_at AS signup_at,
       MIN(pf.created_at) AS first_patient_at,
       MIN(s.created_at) AS first_session_at,
       MIN(r.created_at) AS first_report_at,
       MIN(rr.created_at) AS first_rating_at,
       EXTRACT(EPOCH FROM (MIN(s.created_at) - u.created_at)) / 3600
           AS hours_to_first_session
FROM users u
LEFT JOIN patient_files pf ON pf.therapist_id = u.id AND pf.deleted_at IS NULL
LEFT JOIN sessions s ON s.therapist_id = u.id AND s.deleted_at IS NULL AND s.status = 'COMPLETED'
LEFT JOIN reports r ON r.session_id = s.id
LEFT JOIN report_ratings rr ON rr.therapist_id = u.id
WHERE u.role = 'THERAPIST' AND u.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
GROUP BY 1, 2;

-- V7: Token utilization — nie wymaga filtra (operuje na subskrypcjach/org, nie na email)
-- v_analytics_token_util zostaje bez zmian
