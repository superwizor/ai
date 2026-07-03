-- Seat allocations + assignments (docs/38 §3).
--
-- org_seat_allocations rows are written by billing-svc
-- (AdminSetSeatAllocations); identity-svc only READS them for the
-- seat-limit checks in InviteTherapist / SetTherapistStatus, and
-- writes seat_assignments (the occupancy ledger) when a therapist
-- joins, is deactivated, or is reactivated. Same-PG-instance
-- precedent: RegisterOrganization already seeds subscriptions.

-- name: GetSeatAllocationByID :one
SELECT id, organization_id, plan_id, seats, price_gross_per_seat,
       currency_code, created_at, updated_at
FROM org_seat_allocations
WHERE id = $1;

-- name: GetSeatAllocationForUpdate :one
-- Row-locked read for the seat-limit check: locking the allocation row
-- serializes concurrent InviteTherapist / SetTherapistStatus(reactivate)
-- calls on the same allocation so the last free seat can't be
-- double-booked. Callers MUST run this inside a tx.
SELECT id, organization_id, plan_id, seats, price_gross_per_seat,
       currency_code, created_at, updated_at
FROM org_seat_allocations
WHERE id = $1
FOR UPDATE;

-- name: CountActiveSeatAssignments :one
-- The occupied half of the occupancy formula. FOR the seat-limit
-- check callers should run this inside a tx AFTER
-- pg_advisory_xact_lock on the allocation id to avoid double-booking
-- the last seat under concurrency.
SELECT COUNT(*) FROM seat_assignments
WHERE allocation_id = $1 AND unassigned_at IS NULL;

-- name: CreateSeatAssignment :one
INSERT INTO seat_assignments (user_id, allocation_id)
VALUES ($1, $2)
RETURNING id, user_id, allocation_id, assigned_at, unassigned_at;

-- name: CloseActiveSeatAssignmentForUser :exec
-- Deactivation frees the seat. Idempotent — no open row is a no-op.
UPDATE seat_assignments
SET unassigned_at = now()
WHERE user_id = $1 AND unassigned_at IS NULL;

-- name: GetLatestSeatAssignmentForUser :one
-- Reactivation re-occupies a seat in the therapist's most recent
-- allocation (open or closed row — the newest wins).
SELECT id, user_id, allocation_id, assigned_at, unassigned_at
FROM seat_assignments
WHERE user_id = $1
ORDER BY assigned_at DESC
LIMIT 1;

-- name: SetUserActiveStatus :one
-- Reversible activation toggle. deactivated_at doubles as the audit
-- timestamp of the LAST deactivation (cleared on reactivate).
UPDATE users
SET is_active = $2,
    deactivated_at = CASE WHEN $2 THEN NULL ELSE now() END
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;
