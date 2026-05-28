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

-- name: AdminListAuditEvents :many
-- Global cross-org audit log for the /admin/audit page. LEFT JOINs to
-- users so we can both ILIKE-filter on actor_email AND emit the email
-- in the result row without a separate roundtrip per entry. All
-- filters AND together; NULL/empty narg means "no filter on that axis".
-- Cursor pagination on (occurred_at, id) descending.
SELECT
    ae.id,
    ae.actor_user_id,
    ae.organization_id,
    ae.action,
    ae.resource_type,
    ae.resource_id,
    ae.metadata,
    ae.ip_address,
    ae.user_agent,
    ae.occurred_at,
    ae.reason,
    u.email AS actor_email
FROM audit_events ae
LEFT JOIN users u ON u.id = ae.actor_user_id
WHERE (
        sqlc.narg(actor_email_search)::text IS NULL
        OR u.email ILIKE '%' || sqlc.narg(actor_email_search)::text || '%'
      )
  AND (sqlc.narg(action_filter)::text IS NULL OR ae.action = sqlc.narg(action_filter)::text)
  AND (sqlc.narg(since_ts)::timestamptz IS NULL OR ae.occurred_at >= sqlc.narg(since_ts)::timestamptz)
  AND (sqlc.narg(until_ts)::timestamptz IS NULL OR ae.occurred_at <= sqlc.narg(until_ts)::timestamptz)
  AND (
        sqlc.narg(after_occurred_at)::timestamptz IS NULL
        OR (ae.occurred_at, ae.id) < (sqlc.narg(after_occurred_at)::timestamptz, sqlc.narg(after_id)::uuid)
      )
ORDER BY ae.occurred_at DESC, ae.id DESC
LIMIT sqlc.arg(page_size);
