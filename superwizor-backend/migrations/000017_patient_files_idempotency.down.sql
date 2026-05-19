DROP INDEX IF EXISTS ux_patient_files_idempotency;
ALTER TABLE patient_files DROP COLUMN IF EXISTS idempotency_key;
