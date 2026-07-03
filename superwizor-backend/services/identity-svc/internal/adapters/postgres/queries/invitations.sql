-- name: CreateInvitation :one
-- Idempotent on (organization_id, email). The unique constraint
-- collides for a second invite to the same email — handler reads the
-- unique-violation, decides whether to refresh the token (current
-- design: just return the existing row; client retries the same link).
--
-- invited_role: THERAPIST (team invite) or ORG_ADMIN (manager invite
-- from AdminCreateOrganization). allocation_id pins a THERAPIST invite
-- to a seat allocation; the pending invite reserves that seat.
INSERT INTO invitations (
    organization_id, invited_by_user, email, token_hash, expires_at,
    invited_role, allocation_id, invited_first_name, invited_last_name,
    patient_file_id
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
RETURNING *;

-- name: CountPendingInvitationsForAllocation :one
-- Seat-reservation half of the occupancy formula (docs/38 §3):
-- occupancy = active seat_assignments + pending unexpired invitations.
SELECT COUNT(*) FROM invitations
WHERE allocation_id = $1 AND accepted_at IS NULL AND expires_at > now();

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
