-- name: CreateAuditEvent :one
-- Used by every SUPERWIZOR_ADMIN mutation. reason is REQUIRED here at the
-- handler level (>=10 chars) but NULL-allowed at schema level so legacy
-- non-admin code paths don't have to fill it.
INSERT INTO audit_events (
    actor_user_id, organization_id, action,
    resource_type, resource_id, metadata, reason
) VALUES (
    sqlc.narg(actor_user_id),
    sqlc.narg(organization_id),
    sqlc.arg(action),
    sqlc.arg(resource_type),
    sqlc.narg(resource_id),
    sqlc.arg(metadata),
    sqlc.narg(reason)
)
RETURNING *;

-- name: ListAuditEventsByOrg :many
-- The "recent_audit" panel in the admin org-detail view (docs/18 §13.7).
SELECT * FROM audit_events
WHERE organization_id = $1
ORDER BY occurred_at DESC
LIMIT $2;
