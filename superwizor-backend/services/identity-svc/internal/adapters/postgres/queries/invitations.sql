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
-- revoked_at IS NULL: docs/42 — an explicitly revoked invitation is
-- dead even if the link is still within TTL.
SELECT * FROM invitations
WHERE token_hash = $1 AND accepted_at IS NULL AND revoked_at IS NULL
  AND expires_at > now();

-- name: MarkInvitationAccepted :exec
UPDATE invitations
SET accepted_at = now(), accepted_user_id = $2
WHERE id = $1;

-- name: ListPendingInvitationsByOrg :many
SELECT * FROM invitations
WHERE organization_id = $1 AND accepted_at IS NULL
ORDER BY created_at DESC;

-- name: ListPendingManagerInvitationsByOrg :many
-- docs/38 PR14: pending ORG_ADMIN (manager) invites for the org panel.
SELECT * FROM invitations
WHERE organization_id = $1 AND accepted_at IS NULL AND invited_role = 'ORG_ADMIN'
ORDER BY created_at DESC;

-- name: RevokeManagerInvitation :execrows
-- docs/38 PR14: hard-delete a PENDING ORG_ADMIN invite in the org.
-- Guarded to accepted_at IS NULL + invited_role = 'ORG_ADMIN' so a
-- therapist/client invite or an accepted row can't be removed here.
DELETE FROM invitations
WHERE id = $1 AND organization_id = $2
  AND accepted_at IS NULL AND invited_role = 'ORG_ADMIN';

-- name: ListTherapistsInOrgAll :many
-- Returns both active (deleted_at IS NULL) THERAPISTs in the org AND
-- pending invites. The handler joins/merges them into a single
-- ListTherapistsResponse. We DON'T fetch ORG_ADMIN here because the
-- therapists tab in the org-admin UI is about practitioners, not co-admins.
SELECT * FROM users
WHERE organization_id = $1 AND role = 'THERAPIST' AND deleted_at IS NULL
ORDER BY created_at ASC;

-- name: CountPendingInvitationsForAllocationExcluding :one
-- Re-invite variant of the occupancy count: the invitation being
-- refreshed releases its old reservation in the same UPDATE, so it
-- must not be counted against the target allocation.
SELECT COUNT(*) FROM invitations
WHERE allocation_id = $1 AND accepted_at IS NULL AND expires_at > now()
  AND id <> $2;

-- name: RevokePatientInvitation :execrows
-- docs/42: therapist-initiated revoke of the kartoteka's pending
-- client invitation. Idempotent (second call affects 0 rows).
UPDATE invitations
SET revoked_at = now()
WHERE patient_file_id = $1 AND accepted_at IS NULL AND revoked_at IS NULL;

-- name: IncrementInvitationCodeAttempts :one
-- docs/42: atomic wrong-pairing-code counter; caller blocks at >= 5.
UPDATE invitations
SET code_attempts = code_attempts + 1
WHERE id = $1
RETURNING code_attempts;

-- name: SetInvitationPairingCode :exec
-- docs/42: stamps/rotates the pairing-code hash; resets the attempt
-- counter and clears any revocation (deliberate re-invite).
UPDATE invitations
SET pairing_code_hash = $2, code_attempts = 0, revoked_at = NULL
WHERE id = $1;
