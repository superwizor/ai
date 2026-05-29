-- name: GetOrganizationByID :one
SELECT * FROM organizations
WHERE id = $1 AND deleted_at IS NULL;

-- name: CreateOrganization :one
INSERT INTO organizations (legal_name, tax_id, vat_id_eu, type, headquarters_address_id)
VALUES (
    sqlc.arg(legal_name),
    sqlc.narg(tax_id),
    sqlc.narg(vat_id_eu),
    sqlc.arg(type),
    sqlc.narg(headquarters_address_id)
)
RETURNING *;

-- name: SetOrganizationPrimaryAdmin :exec
UPDATE organizations
SET primary_admin_user_id = $2
WHERE id = $1 AND deleted_at IS NULL;

-- name: UpdateOrganization :one
-- Selective UPDATE — every column uses COALESCE(sqlc.narg, current). Pass
-- NULL on any narg you don't want to touch. legal_name and type collapse
-- to their existing value when NULL is passed, so they're effectively
-- partial too.
UPDATE organizations SET
    legal_name              = COALESCE(sqlc.narg(legal_name), legal_name),
    tax_id                  = COALESCE(sqlc.narg(tax_id), tax_id),
    vat_id_eu               = COALESCE(sqlc.narg(vat_id_eu), vat_id_eu),
    type                    = COALESCE(sqlc.narg(type), type),
    headquarters_address_id = COALESCE(sqlc.narg(headquarters_address_id), headquarters_address_id),
    primary_admin_user_id   = COALESCE(sqlc.narg(primary_admin_user_id), primary_admin_user_id)
WHERE id = sqlc.arg(id) AND deleted_at IS NULL
RETURNING *;

-- name: ListOrganizations :many
-- Cursor pagination keyed on (created_at, id). Pass an empty cursor for the
-- first page; for subsequent pages pass the last row's (created_at, id).
SELECT * FROM organizations
WHERE deleted_at IS NULL
  AND (
      sqlc.narg(search_term)::text IS NULL
      OR legal_name ILIKE '%' || sqlc.narg(search_term)::text || '%'
  )
  AND (
      sqlc.narg(after_created_at)::timestamptz IS NULL
      OR (created_at, id) < (sqlc.narg(after_created_at)::timestamptz, sqlc.narg(after_id)::uuid)
  )
ORDER BY created_at DESC, id DESC
LIMIT sqlc.arg(page_size);

-- name: CountTherapistsInOrg :one
SELECT COUNT(*)::int AS therapists_count
FROM users
WHERE organization_id = $1
  AND role IN ('THERAPIST', 'ORG_ADMIN')
  AND deleted_at IS NULL;
