-- name: GetUserOrganizationID :one
-- Resolves users.organization_id for a therapist — used by
-- clinical-svc.GetMyBillingState (proxy to billing-svc.GetSubscription)
-- to derive the org from the auth-context user_id.
--
-- Returns NULL via pgtype.UUID when the user isn't bound to an org
-- yet (rare after the trial-signup bootstrap — but handled
-- defensively in the caller as FailedPrecondition).
SELECT organization_id
FROM users
WHERE id = $1 AND deleted_at IS NULL;

-- name: GetUserDisplayName :one
-- first_name + last_name for a user (therapist), used by
-- SavePatientNote to populate the action-plan e-mail's
-- therapist_display_name. Both columns are NOT NULL on the users table
-- (migration 000003) so no null handling is needed here.
SELECT first_name, last_name
FROM users
WHERE id = $1 AND deleted_at IS NULL;
