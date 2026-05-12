-- Revert 000014: back to ON DELETE SET NULL semantics. Doesn't undo
-- any cascading DELETEs already done while CASCADE was active.
ALTER TABLE patient_files DROP CONSTRAINT IF EXISTS patient_files_patient_id_fkey;
ALTER TABLE patient_files
  ADD CONSTRAINT patient_files_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE SET NULL;
