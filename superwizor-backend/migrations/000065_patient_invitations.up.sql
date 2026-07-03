-- 000065: Client (patient) panel invitations (docs/39 §3).
--
-- The kartoteka's "Zaproś klienta" reuses the docs/38 magic-link
-- machinery: invited_role gains 'PATIENT', and a patient invite is
-- BOUND to its kartoteka via patient_file_id. Acceptance does NOT
-- create a user — it attaches firebase_uid/email to the existing
-- users(role=PATIENT) row the kartoteka already points at (D1).

ALTER TABLE invitations DROP CONSTRAINT chk_invitations_invitable_role;
ALTER TABLE invitations ADD CONSTRAINT chk_invitations_invitable_role
  CHECK (invited_role IN ('THERAPIST', 'ORG_ADMIN', 'PATIENT'));

-- 000063's allocation-by-role check enumerated THERAPIST/ORG_ADMIN
-- only — a PATIENT row matched neither branch and was rejected.
-- Re-state it with the PATIENT case (never seat-pinned).
ALTER TABLE invitations DROP CONSTRAINT chk_invitations_allocation_by_role;
ALTER TABLE invitations ADD CONSTRAINT chk_invitations_allocation_by_role
  CHECK (
      (invited_role = 'ORG_ADMIN' AND allocation_id IS NULL)
   OR (invited_role = 'PATIENT'   AND allocation_id IS NULL)
   OR (invited_role = 'THERAPIST')
  );

ALTER TABLE invitations ADD COLUMN patient_file_id UUID
  REFERENCES patient_files(id) ON DELETE CASCADE;

COMMENT ON COLUMN invitations.patient_file_id IS
    'Kartoteka a PATIENT invite belongs to (docs/39). NULL for '
    'THERAPIST/ORG_ADMIN invites.';

-- A patient invite without its kartoteka is meaningless; other roles
-- must not carry one.
ALTER TABLE invitations ADD CONSTRAINT chk_invitations_patient_binding
  CHECK (
      (invited_role = 'PATIENT' AND patient_file_id IS NOT NULL)
   OR (invited_role <> 'PATIENT' AND patient_file_id IS NULL)
  );

-- One pending client invitation per kartoteka (re-invite refreshes the
-- token on the same row, mirroring the (org,email) refresh path).
CREATE UNIQUE INDEX uq_invitations_patient_file_pending
    ON invitations(patient_file_id)
    WHERE accepted_at IS NULL AND invited_role = 'PATIENT';
