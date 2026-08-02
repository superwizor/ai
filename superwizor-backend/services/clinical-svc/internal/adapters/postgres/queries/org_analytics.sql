-- Org analytics (docs/38 §7) — per-therapist METADATA aggregates for
-- the ORG_ADMIN dashboard. Hard privacy boundary (§7.3): counts,
-- durations and dates only. No transcript/report/note content, no
-- patient identifiers ever leave this query.

-- name: GetOrgTherapistMetrics :many
-- $1 = organization_id, $2 = window start (timestamptz).
-- Sessions / new patients / ratings are windowed; active_patients is
-- a point-in-time count of open kartoteki.
SELECT
    u.id AS therapist_id,
    u.first_name,
    u.last_name,
    u.is_active,
    COUNT(s.id) FILTER (WHERE s.status = 'COMPLETED')::int AS sessions_completed,
    COUNT(s.id) FILTER (WHERE s.status = 'FAILED')::int AS sessions_failed,
    COUNT(s.id) FILTER (WHERE s.status IN ('CANCELED', 'CANCELLED_BY_USER'))::int AS sessions_cancelled,
    COALESCE(SUM(s.duration_seconds) FILTER (WHERE s.status = 'COMPLETED'), 0)::bigint AS total_duration_seconds,
    COUNT(s.id) FILTER (WHERE s.status = 'COMPLETED' AND s.report_viewed_at IS NOT NULL)::int AS sessions_report_viewed,
    MAX(s.session_date)::date AS last_session_date,
    (SELECT COUNT(*) FROM patient_files pf
      WHERE pf.therapist_id = u.id AND pf.deleted_at IS NULL
        AND pf.is_process_closed = FALSE)::int AS active_patients,
    (SELECT COUNT(*) FROM patient_files pf
      WHERE pf.therapist_id = u.id AND pf.deleted_at IS NULL
        AND pf.created_at >= $2)::int AS new_patients,
    (SELECT COUNT(*) FROM report_ratings rr
      WHERE rr.therapist_id = u.id AND rr.rating = 'positive'
        AND rr.created_at >= $2)::int AS ratings_positive,
    (SELECT COUNT(*) FROM report_ratings rr
      WHERE rr.therapist_id = u.id AND rr.rating = 'negative'
        AND rr.created_at >= $2)::int AS ratings_negative
FROM users u
LEFT JOIN sessions s
       ON s.therapist_id = u.id
      AND s.deleted_at IS NULL
      AND s.created_at >= $2
WHERE u.organization_id = $1
  AND u.deleted_at IS NULL
  -- Menedżer, który sam przyjmuje pacjentów (SetManagerTherapistSeat),
  -- prowadzi sesje jak każdy inny praktyk — jego prawem do praktykowania
  -- jest MIEJSCE w planie, nie rola. Filtr wyłącznie po roli ukrywałby
  -- jego sesje w statystykach organizacji, mimo że liczą się do limitu.
  -- ORG_ADMIN bez miejsca zostaje poza zestawieniem: nie praktykuje.
  AND (
        u.role = 'THERAPIST'
     OR (u.role = 'ORG_ADMIN' AND EXISTS (
            SELECT 1 FROM seat_assignments sa
            WHERE sa.user_id = u.id AND sa.unassigned_at IS NULL))
  )
GROUP BY u.id, u.first_name, u.last_name, u.is_active
ORDER BY u.last_name, u.first_name;
-- name: OrgAnalyticsKPIs :one
-- KPI strip + time-saved session counts, one round trip. All scoped to
-- the org's therapists; sessions soft-delete-aware.
SELECT
    (SELECT COUNT(DISTINCT s.therapist_id) FROM sessions s
      JOIN users u ON u.id = s.therapist_id
      WHERE u.organization_id = $1 AND s.deleted_at IS NULL
        AND s.created_at >= now() - interval '7 days')::int AS kpi_wau,
    (SELECT COUNT(*) FROM sessions s
      JOIN users u ON u.id = s.therapist_id
      WHERE u.organization_id = $1 AND s.deleted_at IS NULL
        AND s.created_at >= date_trunc('week', now()))::int AS kpi_sessions_this_week,
    (SELECT COALESCE(AVG(s.duration_seconds) / 60.0, 0) FROM sessions s
      JOIN users u ON u.id = s.therapist_id
      WHERE u.organization_id = $1 AND s.deleted_at IS NULL
        AND s.status = 'COMPLETED' AND s.duration_seconds IS NOT NULL
        AND s.created_at >= now() - interval '90 days')::float8 AS kpi_avg_session_duration,
    (SELECT COUNT(*) FROM sessions s
      JOIN users u ON u.id = s.therapist_id
      WHERE u.organization_id = $1 AND s.deleted_at IS NULL
        AND s.created_at >= date_trunc('month', now()))::int AS sessions_this_month,
    (SELECT COUNT(*) FROM sessions s
      JOIN users u ON u.id = s.therapist_id
      WHERE u.organization_id = $1 AND s.deleted_at IS NULL
        AND s.created_at >= date_trunc('year', now()))::int AS sessions_this_year;

-- name: OrgWeeklySessionTrend :many
-- Sessions per ISO week (last 9 weeks incl. current) + distinct
-- therapists + avg completed duration — one scan feeds three charts.
SELECT
    to_char(date_trunc('week', s.created_at), 'IYYY-IW') AS week,
    COUNT(*)::int AS sessions,
    COUNT(DISTINCT s.therapist_id)::int AS active_therapists,
    COALESCE(AVG(s.duration_seconds) FILTER (WHERE s.status = 'COMPLETED') / 60.0, 0)::float8 AS avg_duration_min
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE u.organization_id = $1 AND s.deleted_at IS NULL
  AND s.created_at >= date_trunc('week', now()) - interval '8 weeks'
GROUP BY 1
ORDER BY 1;

-- name: OrgHourlyHeatmap :many
-- Day-of-week × hour recording histogram, last 90 days.
SELECT
    EXTRACT(dow FROM s.created_at)::int AS day_of_week,
    EXTRACT(hour FROM s.created_at)::int AS hour,
    COUNT(*)::bigint AS count
FROM sessions s
JOIN users u ON u.id = s.therapist_id
WHERE u.organization_id = $1 AND s.deleted_at IS NULL
  AND s.created_at >= now() - interval '90 days'
GROUP BY 1, 2;

-- name: OrgTherapistUtilization :many
-- Token utilization % per THERAPIST per counter period (docs/38 §7.2)
-- — the per-seat mirror of the admin per-org heatmap. Week label =
-- ISO week of period_start.
SELECT
    (u.first_name || ' ' || u.last_name)::text AS therapist_name,
    to_char(date_trunc('week', c.period_start), 'IYYY-IW') AS week,
    CASE WHEN c.tokens_limit > 0
         THEN ROUND((c.tokens_used::numeric / c.tokens_limit) * 100)
         ELSE 0 END::float8 AS value
FROM usage_counters c
JOIN users u ON u.id = c.therapist_id
JOIN subscriptions sub ON sub.id = c.subscription_id
WHERE sub.organization_id = $1
  AND c.therapist_id IS NOT NULL
  AND c.period_start >= now() - interval '180 days'
ORDER BY therapist_name, week;
