-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL;

-- name: GetUserByFirebaseUID :one
SELECT * FROM users WHERE firebase_uid = $1 AND deleted_at IS NULL;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL;

-- name: CreateUser :one
INSERT INTO users (
    role, firebase_uid, email,
    first_name, last_name, ui_language, timezone, has_accepted_tos
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: UpdateProfile :one
UPDATE users SET
    first_name = COALESCE(sqlc.narg(first_name), first_name),
    last_name = COALESCE(sqlc.narg(last_name), last_name),
    professional_title = sqlc.narg(professional_title),
    credentials_number = sqlc.narg(credentials_number),
    biography = sqlc.narg(biography),
    phone_number = sqlc.narg(phone_number)
WHERE id = sqlc.arg(id) AND deleted_at IS NULL
RETURNING *;

-- name: SoftDeleteUser :exec
UPDATE users SET deleted_at = now() WHERE id = $1;

-- name: ListTherapistsByOrganization :many
SELECT * FROM users
WHERE organization_id = $1
  AND role = 'THERAPIST'
  AND deleted_at IS NULL
ORDER BY last_name, first_name;

-- name: GetReportPreferences :one
-- Returns the raw JSONB. Empty object {} when the user has never
-- customized; Go layer turns that into the default ReportPreferences.
SELECT report_preferences
FROM users
WHERE id = $1 AND deleted_at IS NULL;

-- name: UpdateReportPreferences :one
-- Replaces the entire preferences blob. The Go handler sanitizes
-- and validates the blob shape before calling this; sqlc just
-- writes whatever JSONB it gets. Returns the post-update value so
-- the gRPC handler can echo it back without a second SELECT.
UPDATE users
SET report_preferences = $2
WHERE id = $1 AND deleted_at IS NULL
RETURNING report_preferences;
