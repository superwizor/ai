-- 000062: Reversible therapist deactivation + seat assignments (docs/38 §3).
--
-- is_active=false is an ORG_ADMIN action (SetTherapistStatus): the account
-- is blocked at ValidateToken ("ACCOUNT_DEACTIVATED") but ALL clinical data
-- stays untouched, and the seat is freed for someone else. This is distinct
-- from soft-delete (users.deleted_at / RemoveTherapist), which remains the
-- RODO path.
--
-- seat_assignments is the occupancy ledger: one open row (unassigned_at
-- IS NULL) = one seat taken in the allocation. History is kept — a
-- deactivated-then-reactivated therapist gets a NEW row, so "who occupied
-- which seat when" stays auditable.

ALTER TABLE users
  ADD COLUMN is_active BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE users
  ADD COLUMN deactivated_at TIMESTAMPTZ;

COMMENT ON COLUMN users.is_active IS
    'FALSE = reversibly deactivated by ORG_ADMIN (SetTherapistStatus). '
    'Blocked at ValidateToken with ACCOUNT_DEACTIVATED; data untouched. '
    'Independent of deleted_at (soft-delete = RODO path).';

CREATE TABLE seat_assignments (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    allocation_id UUID NOT NULL REFERENCES org_seat_allocations(id) ON DELETE CASCADE,
    assigned_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    unassigned_at TIMESTAMPTZ,          -- NULL = seat currently occupied

    CONSTRAINT chk_seat_assignment_window CHECK (
        unassigned_at IS NULL OR unassigned_at >= assigned_at
    )
);

-- A user occupies at most one seat at a time (single-role MVP).
CREATE UNIQUE INDEX uq_one_active_seat_per_user
    ON seat_assignments(user_id) WHERE unassigned_at IS NULL;

-- Occupancy count per allocation is the hot query for seat-limit checks.
CREATE INDEX idx_seat_assignments_allocation_active
    ON seat_assignments(allocation_id) WHERE unassigned_at IS NULL;
