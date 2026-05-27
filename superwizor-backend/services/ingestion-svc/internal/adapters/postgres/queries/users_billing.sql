-- name: GetUserOrganizationID :one
-- Resolves users.organization_id for a therapist — used by ingestion-svc
-- post-commit to populate the org_id field on billing-svc.ReserveCredit
-- (which requires both therapist + organization to scope quota correctly).
--
-- Returns NULL via pgtype.UUID when the user isn't bound to an org yet
-- (rare today after slice 4 bootstrap, but handled defensively in the
-- caller — no reservation attempted in that case).
SELECT organization_id
FROM users
WHERE id = $1 AND deleted_at IS NULL;
