-- Reverse 000013. We intentionally do NOT delete backfilled patient
-- users — rolling back the schema shouldn't drop PII that the
-- therapist may have edited since deploy.

-- 4. (no-op) backfilled patient users stay
-- 3. restore RESTRICT on patient_files.patient_id
ALTER TABLE patient_files DROP CONSTRAINT IF EXISTS patient_files_patient_id_fkey;
ALTER TABLE patient_files
  ADD CONSTRAINT patient_files_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE RESTRICT;

-- 2. drop the partial unique index
DROP INDEX IF EXISTS ux_patient_files_therapist_alias;

-- 1. restore NOT NULL + drop the partial CHECKs.
-- NOTE: this fails if any patient row already has NULL firebase_uid/email
-- (which happens after the migration runs). Operator must wipe patient
-- rows before downgrade.
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_firebase_uid_required_for_non_patient;
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_email_required_for_non_patient;
ALTER TABLE users ALTER COLUMN firebase_uid SET NOT NULL;
ALTER TABLE users ALTER COLUMN email        SET NOT NULL;
