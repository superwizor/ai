-- 000011: sessions.name
--
-- Adds a free-text label on each session that the therapist can rename.
-- Default at INSERT time (set by ingestion-svc.CompleteAudioUpload):
--   "<modalities.display_name> <session_number>"  →  "Cognitive Behavioral Therapy 3"
--
-- Existing rows are backfilled below using the same formula. Modality
-- join walks through patient_files. If the join misses (data integrity
-- issue), fall back to a generic label so the column never stays NULL.
--
-- Kept NULLABLE on purpose:
--   1. Avoids a deploy ordering coupling — ingestion-svc populating the
--      column doesn't have to land before this migration runs.
--   2. Renames go through clinical-svc.UpdateSession, which validates
--      non-empty input at the API layer rather than the DB.

ALTER TABLE sessions ADD COLUMN name VARCHAR(255);

-- Backfill existing rows.
UPDATE sessions s
SET name = COALESCE(m.display_name, 'Sesja') || ' ' || s.session_number
FROM patient_files pf
JOIN modalities m ON m.id = pf.modality_id
WHERE s.patient_file_id = pf.id
  AND s.name IS NULL;

-- Any sessions whose join failed (orphaned patient_file_id, missing
-- modality) get a generic label so no row remains NULL.
UPDATE sessions
SET name = 'Sesja ' || session_number
WHERE name IS NULL;
