-- 000063: Invitations carry a role and a seat allocation (docs/38 §3).
--
-- invited_role: AdminCreateOrganization invites org managers — they must
-- land as ORG_ADMIN, not THERAPIST (000035 hard-coded THERAPIST; docs/18
-- R4 single-role stays: the value is fixed at invite time, never
-- escalated later). AcceptInvitation copies this into users.role.
--
-- allocation_id: a therapist invite is pinned to a seat allocation
-- (org × plan). A pending, unexpired invitation RESERVES one seat in
-- that allocation until accepted or expired (7 days). NULL for
-- ORG_ADMIN invites — managers don't occupy seats.
--
-- invited_first/last_name: the org manager types the therapist's name
-- at invite time (docs/38 §0.3). Stored so the pending-invitations list
-- can show who was invited and AcceptInvitation can prefill; the
-- acceptor's own input still wins on accept.

ALTER TABLE invitations
  ADD COLUMN invited_role user_role NOT NULL DEFAULT 'THERAPIST';
ALTER TABLE invitations
  ADD COLUMN allocation_id UUID REFERENCES org_seat_allocations(id) ON DELETE SET NULL;
ALTER TABLE invitations
  ADD COLUMN invited_first_name VARCHAR(100);
ALTER TABLE invitations
  ADD COLUMN invited_last_name VARCHAR(100);

-- Invites can only mint the two invitable roles — never SUPERWIZOR_ADMIN
-- (platform staff are provisioned out-of-band), never PATIENT.
ALTER TABLE invitations
  ADD CONSTRAINT chk_invitations_invitable_role
  CHECK (invited_role IN ('THERAPIST', 'ORG_ADMIN'));

-- Therapist invites must be seat-pinned; manager invites must not be.
ALTER TABLE invitations
  ADD CONSTRAINT chk_invitations_allocation_by_role
  CHECK (
      (invited_role = 'ORG_ADMIN'  AND allocation_id IS NULL)
   OR (invited_role = 'THERAPIST')
  );

-- Seat-reservation count per allocation: pending (unaccepted) invites only.
CREATE INDEX idx_invitations_allocation_pending
    ON invitations(allocation_id)
    WHERE accepted_at IS NULL AND allocation_id IS NOT NULL;
