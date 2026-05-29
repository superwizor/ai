-- name: CreateInvitation :one
-- Idempotent on (organization_id, email). The unique constraint
-- collides for a second invite to the same email — handler reads the
-- unique-violation, decides whether to refresh the token (current
-- design: just return the existing row; client retries the same link).
INSERT INTO invitations (
    organization_id, invited_by_user, email, token_hash, expires_at
) VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetInvitationByOrgEmail :one
SELECT * FROM invitations
WHERE organization_id = $1 AND email = $2 AND accepted_at IS NULL;

-- name: GetUnacceptedInvitationByTokenHash :one
-- The hot path on AcceptInvitation. Uses idx_invitations_token_hash
-- partial index (WHERE accepted_at IS NULL).
SELECT * FROM invitations
WHERE token_hash = $1 AND accepted_at IS NULL AND expires_at > now();

-- name: MarkInvitationAccepted :exec
UPDATE invitations
SET accepted_at = now(), accepted_user_id = $2
WHERE id = $1;

-- name: ListPendingInvitationsByOrg :many
SELECT * FROM invitations
WHERE organization_id = $1 AND accepted_at IS NULL
ORDER BY created_at DESC;

-- name: ListTherapistsInOrgAll :many
-- Returns both active (deleted_at IS NULL) THERAPISTs in the org AND
-- pending invites. The handler joins/merges them into a single
-- ListTherapistsResponse. We DON'T fetch ORG_ADMIN here because the
-- therapists tab in the org-admin UI is about practitioners, not co-admins.
SELECT * FROM users
WHERE organization_id = $1 AND role = 'THERAPIST' AND deleted_at IS NULL
ORDER BY created_at ASC;
