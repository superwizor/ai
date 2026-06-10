-- name: GetWAU :one
-- CROSS-SERVICE READ: analytics-only
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
SELECT COUNT(*)::bigint AS count
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.created_at >= NOW() - INTERVAL '7 days'
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
FROM v_analytics_activation;

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
  AND u.email NOT LIKE '%@example.test';

-- name: GetWauTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(week, 'YYYY-IW') AS label,
  active_therapists::float AS value
FROM v_analytics_wau
WHERE week >= $1::timestamptz
ORDER BY week ASC;

-- name: GetSessionsTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(date_trunc('week', s.created_at), 'YYYY-IW') AS label,
  COUNT(*)::float AS value
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= $1
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetRegistrationsTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(date_trunc('week', created_at), 'YYYY-IW') AS label,
  COUNT(*)::float AS value
FROM users
WHERE role = 'THERAPIST' AND deleted_at IS NULL
  AND email NOT LIKE '%@superwizor.test'
  AND email NOT LIKE '%@example.com'
  AND email NOT LIKE '%@example.test'
  AND created_at >= $1
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetPlanDistribution :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  sp.display_name AS plan_name,
  COUNT(*)::bigint AS count
FROM subscriptions s
JOIN subscription_plans sp ON s.plan_id = sp.id
WHERE s.status = 'ACTIVE'
GROUP BY 1;

-- name: GetUnitEconomicsKPIs :one
-- CROSS-SERVICE READ: analytics-only
SELECT 
  COALESCE(AVG(total_cost_usd), 0.0)::float AS avg_cost_per_session,
  COALESCE(SUM(stt_cost_usd) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days'), 0.0)::float AS monthly_stt_cost,
  COALESCE(SUM(llm_cost_usd) FILTER (WHERE created_at >= NOW() - INTERVAL '30 days'), 0.0)::float AS monthly_llm_cost
FROM v_analytics_session_cost;

-- name: GetAvgTokenUtilization :one
-- CROSS-SERVICE READ: analytics-only
SELECT 
  COALESCE(AVG(utilization_pct), 0.0)::float AS avg_utilization
FROM v_analytics_token_util;

-- name: GetCostTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(date_trunc('week', created_at), 'YYYY-IW') AS label,
  AVG(stt_cost_usd)::float AS stt_cost,
  AVG(llm_cost_usd)::float AS llm_cost,
  AVG(total_cost_usd)::float AS total_cost
FROM v_analytics_session_cost
WHERE created_at >= $1
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetTokenUtilizationHeatmap :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  o.legal_name::text AS org_name,
  TO_CHAR(v.period_start, 'YYYY-IW') AS week,
  AVG(v.utilization_pct)::float AS value
FROM v_analytics_token_util v
JOIN organizations o ON v.organization_id = o.id
GROUP BY 1, 2
ORDER BY 2 ASC, 1 ASC
LIMIT 50;

-- name: GetRevenueTrend :many
-- CROSS-SERVICE READ: analytics-only
-- MRR snapshot: counts active subscriptions per plan tier
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
  TO_CHAR(date_trunc('week', created_at), 'YYYY-IW') AS label,
  SUM(llm_input_tokens)::bigint AS input_tokens,
  SUM(llm_output_tokens)::bigint AS output_tokens
FROM v_analytics_session_cost
WHERE created_at >= $1
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetAIQualityKPIs :one
-- CROSS-SERVICE READ: analytics-only
-- Uses separate subqueries to prevent row multiplication from 1:N joins
SELECT
  COALESCE((SELECT AVG(e2e_seconds) FROM v_analytics_pipeline_latency), 0.0)::float AS avg_pipeline_latency,
  COALESCE(
    (COUNT(*) FILTER (WHERE s.status = 'FAILED' AND s.created_at >= NOW() - INTERVAL '7 days')::float
     / NULLIF(COUNT(*) FILTER (WHERE s.created_at >= NOW() - INTERVAL '7 days'), 0)),
    0.0
  )::float AS failure_rate_7d
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test';

-- name: GetRelabelRate :one
-- CROSS-SERVICE READ: analytics-only
SELECT 
  COALESCE(
    (COUNT(DISTINCT session_id) FILTER (WHERE event_name = 'speaker_labels.updated')::float / NULLIF(COUNT(DISTINCT session_id) FILTER (WHERE event_name = 'upload.finalized'), 0))::float,
    0.0
  )::float AS relabel_rate
FROM analytics_events;

-- name: GetSatisfactionTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(week, 'YYYY-IW') AS label,
  satisfaction_pct::float AS satisfaction_pct
FROM v_analytics_satisfaction
WHERE week >= $1::timestamptz
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
GROUP BY 1
ORDER BY 2 DESC;

-- name: GetLatencyTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(date_trunc('week', session_at), 'YYYY-IW') AS label,
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY e2e_seconds)::float AS p50,
  PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY e2e_seconds)::float AS p95
FROM v_analytics_pipeline_latency
WHERE session_at >= $1
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetFailureRateTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(date_trunc('week', s.created_at), 'YYYY-IW') AS label,
  (COUNT(*) FILTER (WHERE s.status = 'FAILED')::float / COUNT(*))::float AS failure_rate,
  COUNT(*)::bigint AS total,
  COUNT(*) FILTER (WHERE s.status = 'FAILED')::bigint AS failed
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= $1
GROUP BY 1
ORDER BY 1 ASC;

-- name: GetFunnelSteps :one
-- CROSS-SERVICE READ: analytics-only
SELECT 
  COUNT(*)::bigint AS signup_count,
  COUNT(first_patient_at)::bigint AS patient_created_count,
  COUNT(first_session_at)::bigint AS session_completed_count,
  COUNT(first_rating_at)::bigint AS rated_count
FROM v_analytics_activation;

-- name: GetReadReportCount :one
-- CROSS-SERVICE READ: analytics-only
SELECT COUNT(DISTINCT therapist_id)::bigint
FROM analytics_events
WHERE event_name = 'report.read_started';

-- name: GetCohortRetention :many
-- CROSS-SERVICE READ: analytics-only
WITH cohort_sizes AS (
  SELECT 
    date_trunc('week', signup_at) AS cohort_week,
    COUNT(DISTINCT therapist_id)::float AS total_size
  FROM v_analytics_activation
  GROUP BY 1
),
activity AS (
  SELECT 
    s.therapist_id,
    date_trunc('week', s.created_at) AS activity_week
  FROM sessions s
  WHERE s.deleted_at IS NULL
),
cohort_activity AS (
  SELECT 
    date_trunc('week', u.signup_at) AS cohort_week,
    a.activity_week,
    COUNT(DISTINCT u.therapist_id)::float AS active_size
  FROM v_analytics_activation u
  JOIN activity a ON u.therapist_id = a.therapist_id
  WHERE a.activity_week >= date_trunc('week', u.signup_at)
  GROUP BY 1, 2
)
SELECT 
  COALESCE(TO_CHAR(cs.cohort_week, 'YYYY-IW'), '')::text AS cohort,
  COALESCE(TO_CHAR(ca.activity_week, 'YYYY-IW')::text, '')::text AS week,
  COALESCE((ca.active_size / cs.total_size)::float, 0.0)::float AS pct
FROM cohort_sizes cs
JOIN cohort_activity ca ON cs.cohort_week = ca.cohort_week
ORDER BY 1 ASC, 2 ASC
LIMIT 200;

-- name: GetActivationTimeHistogram :many
-- CROSS-SERVICE READ: analytics-only
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
GROUP BY 1;

-- name: GetHourlyHeatmap :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  EXTRACT(DOW FROM s.created_at)::int AS day_of_week,
  EXTRACT(HOUR FROM s.created_at)::int AS hour,
  COUNT(*)::bigint AS count
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
GROUP BY 1, 2
ORDER BY 1 ASC, 2 ASC;

-- name: GetUploadFailuresTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(date_trunc('week', occurred_at), 'YYYY-IW') AS label,
  (COUNT(*) FILTER (WHERE event_name = 'upload.failed')::float / NULLIF(COUNT(*), 0))::float AS failure_rate,
  COUNT(*)::bigint AS total,
  COUNT(*) FILTER (WHERE event_name = 'upload.failed')::bigint AS failed
FROM analytics_events
WHERE event_name IN ('upload.initiated', 'upload.failed')
  AND occurred_at >= $1
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
  AND u.email NOT LIKE '%@example.test';

-- name: GetSessionDurationTrend :many
-- CROSS-SERVICE READ: analytics-only
SELECT 
  TO_CHAR(date_trunc('week', s.created_at), 'YYYY-IW') AS label,
  COALESCE(AVG(s.duration_seconds), 0.0)::float AS value
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE s.deleted_at IS NULL
  AND u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND s.created_at >= $1
GROUP BY 1
ORDER BY 1 ASC;
