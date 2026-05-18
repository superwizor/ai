-- Report-rating queries. Spec: docs/10_REPORT_CUSTOMIZATION.md §5.
-- All paths assume the gRPC handler has already validated that the
-- therapist owns the session that owns the report (auth happens at
-- the handler boundary, not in SQL).

-- name: GetReportRating :one
SELECT * FROM report_ratings
WHERE report_id = $1 AND therapist_id = $2;

-- name: UpsertReportRating :one
-- UPSERT on the unique (report_id, therapist_id) pair so re-rating
-- replaces in place. updated_at is bumped on every conflict — gives
-- analytics a "last-touch" timestamp without a separate column.
INSERT INTO report_ratings (
    report_id, therapist_id, rating, issues, notes, source
) VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (report_id, therapist_id) DO UPDATE SET
    rating     = EXCLUDED.rating,
    issues     = EXCLUDED.issues,
    notes      = EXCLUDED.notes,
    source     = EXCLUDED.source,
    updated_at = now()
RETURNING *;

-- name: ListRecentNegativeRatings :many
-- Pulls the last N negative ratings for a therapist. The
-- suggestion-engine Go code aggregates by chip category. We cap at
-- 5 in production today (the trigger window) but the LIMIT comes
-- from the caller so eval / debugging can ask for more.
SELECT id, report_id, rating, issues, created_at
FROM report_ratings
WHERE therapist_id = $1
  AND rating = 'negative'
ORDER BY created_at DESC
LIMIT $2;

-- ─── preference_suggestions_log ─────────────────────────────

-- name: InsertPreferenceSuggestionLog :exec
-- Telemetry-only. Three action values: 'shown' | 'applied' |
-- 'dismissed' — DB CHECK constraint enforces.
INSERT INTO preference_suggestions_log (
    therapist_id, dimension, from_value, to_value, trigger_count, action
) VALUES ($1, $2, $3, $4, $5, $6);

-- name: GetLatestSuggestionDismissForDimension :one
-- Used by the suggestion engine to honor the 14-day cooldown after
-- a banner is dismissed for a given dimension. Returns the most
-- recent 'dismissed' row for (therapist, dimension) or NotFound.
SELECT id, dimension, from_value, to_value, trigger_count, created_at
FROM preference_suggestions_log
WHERE therapist_id = $1
  AND dimension = $2
  AND action = 'dismissed'
ORDER BY created_at DESC
LIMIT 1;
