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
