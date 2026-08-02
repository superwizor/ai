-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1 AND deleted_at IS NULL;

-- name: GetUserByFirebaseUID :one
SELECT * FROM users WHERE firebase_uid = $1 AND deleted_at IS NULL;

-- name: GetUserByEmail :one
SELECT * FROM users WHERE email = $1 AND deleted_at IS NULL;

-- name: CheckPhoneNumberExists :one
SELECT EXISTS(
    SELECT 1 FROM users WHERE phone_number = $1 AND deleted_at IS NULL
);

-- name: CreateUser :one
INSERT INTO users (
    role, firebase_uid, email,
    first_name, last_name, ui_language, timezone, has_accepted_tos
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: UpdateProfile :one
-- Every column uses COALESCE(narg, current) so a NULL narg = "don't touch
-- this column". The Go handler is responsible for converting empty-string
-- (the iOS legacy contract on fields 2-7 of UpdateProfileRequest) into
-- a nil pointer when "don't change" is intended. New optional fields
-- 8-13 from the proto naturally arrive as nil pointers when unset.
-- See docs/18 D2.
UPDATE users SET
    first_name            = COALESCE(sqlc.narg(first_name), first_name),
    last_name             = COALESCE(sqlc.narg(last_name), last_name),
    professional_title    = COALESCE(sqlc.narg(professional_title), professional_title),
    credentials_number    = COALESCE(sqlc.narg(credentials_number), credentials_number),
    biography             = COALESCE(sqlc.narg(biography), biography),
    phone_number          = COALESCE(sqlc.narg(phone_number), phone_number),
    avatar_url            = COALESCE(sqlc.narg(avatar_url), avatar_url),
    default_modality_id   = COALESCE(sqlc.narg(default_modality_id), default_modality_id),
    ui_language           = COALESCE(sqlc.narg(ui_language), ui_language),
    timezone              = COALESCE(sqlc.narg(timezone), timezone),
    billing_address_id    = COALESCE(sqlc.narg(billing_address_id), billing_address_id),
    has_marketing_consent = COALESCE(sqlc.narg(has_marketing_consent), has_marketing_consent)
WHERE id = sqlc.arg(id) AND deleted_at IS NULL
RETURNING *;

-- name: AdminUpdateUser :one
-- Superwizor-admin variant — accepts the admin-only columns (email, role,
-- organization_id, is_email_verified) plus everything UpdateProfile covers.
-- Every column is selective via COALESCE. The handler enforces the role
-- gate + writes audit_events before calling this.
UPDATE users SET
    email                 = COALESCE(sqlc.narg(email), email),
    role                  = COALESCE(sqlc.narg(role), role),
    organization_id       = COALESCE(sqlc.narg(organization_id), organization_id),
    is_email_verified     = COALESCE(sqlc.narg(is_email_verified), is_email_verified),
    first_name            = COALESCE(sqlc.narg(first_name), first_name),
    last_name             = COALESCE(sqlc.narg(last_name), last_name),
    professional_title    = COALESCE(sqlc.narg(professional_title), professional_title),
    credentials_number    = COALESCE(sqlc.narg(credentials_number), credentials_number),
    biography             = COALESCE(sqlc.narg(biography), biography),
    phone_number          = COALESCE(sqlc.narg(phone_number), phone_number),
    avatar_url            = COALESCE(sqlc.narg(avatar_url), avatar_url),
    default_modality_id   = COALESCE(sqlc.narg(default_modality_id), default_modality_id),
    ui_language           = COALESCE(sqlc.narg(ui_language), ui_language),
    timezone              = COALESCE(sqlc.narg(timezone), timezone),
    billing_address_id    = COALESCE(sqlc.narg(billing_address_id), billing_address_id)
WHERE id = sqlc.arg(id) AND deleted_at IS NULL
RETURNING *;

-- name: SoftDeleteUser :exec
UPDATE users SET deleted_at = now() WHERE id = $1;

-- name: LinkUserToOrganization :exec
-- Used by RegisterOrganization (sets the just-created ORG_ADMIN user's
-- organization_id to the new org) and AcceptInvitation (sets the new
-- THERAPIST's org to the inviting org).
UPDATE users SET organization_id = $2 WHERE id = $1 AND deleted_at IS NULL;

-- name: AdminListUsers :many
SELECT * FROM users
WHERE deleted_at IS NULL
  AND (sqlc.narg(organization_id)::uuid IS NULL OR organization_id = sqlc.narg(organization_id)::uuid)
  AND (sqlc.narg(role_filter)::user_role IS NULL OR role = sqlc.narg(role_filter)::user_role)
  AND (
      sqlc.narg(search_term)::text IS NULL
      OR email ILIKE '%' || sqlc.narg(search_term)::text || '%'
      OR first_name ILIKE '%' || sqlc.narg(search_term)::text || '%'
      OR last_name ILIKE '%' || sqlc.narg(search_term)::text || '%'
  )
  AND (
      sqlc.narg(after_created_at)::timestamptz IS NULL
      OR (created_at, id) < (sqlc.narg(after_created_at)::timestamptz, sqlc.narg(after_id)::uuid)
  )
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg(page_size);

-- name: ListTherapistsByOrganization :many
-- Zakładka ZESPÓŁ w panelu organizacji.
--
-- Rola nie jest tu jedynym kryterium, bo menedżer może sam przyjmować
-- pacjentów (SetManagerTherapistSeat). Takiemu ORG_ADMINowi nie zmieniamy
-- roli — prawem do praktykowania jest MIEJSCE w planie — więc gdyby lista
-- filtrowała wyłącznie po roli, osoba zajmowałaby miejsce i zużywała
-- limit, będąc niewidoczna w zespole i nie do odebrania z panelu.
--
-- ORG_ADMIN BEZ miejsca zostaje poza listą: to czysty menedżer i jego
-- miejsce jest w sekcji Menedżerowie, nie wśród praktykujących.
SELECT u.* FROM users u
WHERE u.organization_id = $1
  AND u.deleted_at IS NULL
  AND (
        u.role = 'THERAPIST'
     OR (u.role = 'ORG_ADMIN' AND EXISTS (
            SELECT 1 FROM seat_assignments sa
            WHERE sa.user_id = u.id AND sa.unassigned_at IS NULL))
  )
ORDER BY u.last_name, u.first_name;

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

-- name: ListManagersByOrganization :many
-- ORG_ADMIN members of an org — the primary-admin transfer candidate
-- pool on /admin/orgs/[id] (docs/38).
SELECT * FROM users
WHERE organization_id = $1 AND role = 'ORG_ADMIN' AND deleted_at IS NULL
ORDER BY created_at ASC;

-- name: StampFirstAppLogin :exec
-- Sets first_app_login_at timestamp on the user's first login from the Flutter app.
-- Idempotent: only updates if first_app_login_at IS NULL.
UPDATE users
SET first_app_login_at = now()
WHERE id = $1 AND first_app_login_at IS NULL AND deleted_at IS NULL;

