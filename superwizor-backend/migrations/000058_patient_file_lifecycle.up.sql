-- 000058: Add lifecycle_status column to patient_files.
--
-- Replaces the Flutter-only SharedPreferences lifecycle with a
-- backend-persisted state: 'ACTIVE' (default), 'COMPLETED', 'PAUSED'.
--
-- The existing is_process_closed boolean is kept for backward
-- compatibility — on writes the backend will derive it from
-- lifecycle_status (COMPLETED ≡ closed).
--
-- Backfill: any existing patient_file with is_process_closed=true
-- gets lifecycle_status='COMPLETED'.

ALTER TABLE patient_files
  ADD COLUMN lifecycle_status TEXT NOT NULL DEFAULT 'ACTIVE';

UPDATE patient_files
  SET lifecycle_status = 'COMPLETED'
  WHERE is_process_closed = true;

-- Constrain valid values at the DB level.
ALTER TABLE patient_files
  ADD CONSTRAINT chk_lifecycle_status
  CHECK (lifecycle_status IN ('ACTIVE', 'COMPLETED', 'PAUSED'));

COMMENT ON COLUMN patient_files.lifecycle_status IS
  'Therapist-managed patient file lifecycle: ACTIVE | COMPLETED | PAUSED. '
  'COMPLETED replaces is_process_closed=true. Default ACTIVE.';
