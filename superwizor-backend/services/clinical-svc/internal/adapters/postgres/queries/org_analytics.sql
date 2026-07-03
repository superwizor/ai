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
  AND u.role = 'THERAPIST'
  AND u.deleted_at IS NULL
GROUP BY u.id, u.first_name, u.last_name, u.is_active
ORDER BY u.last_name, u.first_name;