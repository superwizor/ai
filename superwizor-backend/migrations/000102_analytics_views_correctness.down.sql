-- Przywraca widoki w postaci z migracji 000045 (kubełki w UTC, mnożenie
-- wierszy przez liczbę raportów, liczniki tokenów wszystkich zakresów
-- naraz i bez filtra kont testowych). Ta wersja jest błędna — down istnieje
-- po to, żeby migrację dało się cofnąć, nie dlatego, że jest poprawna.

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

DROP VIEW IF EXISTS v_analytics_token_util CASCADE;
CREATE VIEW v_analytics_token_util AS
SELECT uc.subscription_id,
       sub.organization_id,
       uc.period_start,
       uc.period_end,
       uc.tokens_limit,
       uc.tokens_used,
       ROUND(100.0 * uc.tokens_used / NULLIF(uc.tokens_limit, 0), 1)
           AS utilization_pct
FROM usage_counters uc
JOIN subscriptions sub ON sub.id = uc.subscription_id;
