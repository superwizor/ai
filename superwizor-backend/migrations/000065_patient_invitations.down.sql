DROP INDEX IF EXISTS uq_invitations_patient_file_pending;
ALTER TABLE invitations DROP CONSTRAINT IF EXISTS chk_invitations_patient_binding;
-- NOTE: fails if PATIENT invitations exist — delete them first.
DELETE FROM invitations WHERE invited_role = 'PATIENT';
ALTER TABLE invitations DROP COLUMN IF EXISTS patient_file_id;
ALTER TABLE invitations DROP CONSTRAINT IF EXISTS chk_invitations_allocation_by_role;
ALTER TABLE invitations ADD CONSTRAINT chk_invitations_allocation_by_role
  CHECK (
      (invited_role = 'ORG_ADMIN' AND allocation_id IS NULL)
   OR (invited_role = 'THERAPIST')
  );
ALTER TABLE invitations DROP CONSTRAINT IF EXISTS chk_invitations_invitable_role;
ALTER TABLE invitations ADD CONSTRAINT chk_invitations_invitable_role
  CHECK (invited_role IN ('THERAPIST', 'ORG_ADMIN'));
