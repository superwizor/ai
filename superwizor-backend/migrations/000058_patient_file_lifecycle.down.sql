ALTER TABLE patient_files DROP CONSTRAINT IF EXISTS chk_lifecycle_status;
ALTER TABLE patient_files DROP COLUMN IF EXISTS lifecycle_status;
