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

-- ─── Admin feedback dashboard (SUPERWIZOR_ADMIN only) ──────

-- name: AdminListReportRatings :many
-- Paginated list of all ratings with therapist name/email.
-- Filters (all AND-combined): rating type, review status, therapist search.
-- Test accounts excluded.
SELECT
  rr.id, rr.report_id, rr.therapist_id,
  rr.rating, rr.issues, rr.notes, rr.source,
  rr.admin_review_status, rr.created_at, rr.updated_at,
  u.first_name AS therapist_first_name,
  u.last_name  AS therapist_last_name,
  u.email      AS therapist_email
FROM report_ratings rr
JOIN users u ON u.id = rr.therapist_id
WHERE u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND ($3::text = '' OR rr.rating = $3)
  AND ($4::text = '' OR rr.admin_review_status = $4)
  AND ($5::text = '' OR u.first_name ILIKE '%' || $5 || '%'
       OR u.last_name ILIKE '%' || $5 || '%'
       OR u.email ILIKE '%' || $5 || '%')
ORDER BY rr.created_at DESC
LIMIT $1 OFFSET $2;

-- name: AdminCountReportRatings :one
-- Total count matching the same filters as AdminListReportRatings.
SELECT COUNT(*)::bigint AS count
FROM report_ratings rr
JOIN users u ON u.id = rr.therapist_id
WHERE u.email NOT LIKE '%@superwizor.test'
  AND u.email NOT LIKE '%@example.com'
  AND u.email NOT LIKE '%@example.test'
  AND ($1::text = '' OR rr.rating = $1)
  AND ($2::text = '' OR rr.admin_review_status = $2)
  AND ($3::text = '' OR u.first_name ILIKE '%' || $3 || '%'
       OR u.last_name ILIKE '%' || $3 || '%'
       OR u.email ILIKE '%' || $3 || '%');

-- name: AdminSetRatingReviewStatus :exec
-- Toggles a rating's admin review status (pending ↔ done).
UPDATE report_ratings
SET admin_review_status = $2, updated_at = now()
WHERE id = $1;
