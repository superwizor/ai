DROP INDEX IF EXISTS idx_patient_notes_client_visible;
-- NOTE: fails if CLIENT_NOTE rows exist — they are client data; delete
-- deliberately before downgrading.
DELETE FROM patient_notes WHERE kind = 'CLIENT_NOTE';
ALTER TABLE patient_notes DROP CONSTRAINT IF EXISTS chk_patient_notes_author;
ALTER TABLE patient_notes DROP CONSTRAINT IF EXISTS patient_notes_kind_check;
ALTER TABLE patient_notes ADD CONSTRAINT patient_notes_kind_check
  CHECK (kind IN ('FREE_NOTE', 'ACTION_PLAN'));
ALTER TABLE patient_notes DROP COLUMN IF EXISTS read_by_client_at;
ALTER TABLE patient_notes DROP COLUMN IF EXISTS read_by_therapist_at;
ALTER TABLE patient_notes DROP COLUMN IF EXISTS author_role;
ALTER TABLE patient_notes DROP COLUMN IF EXISTS shared_with_client_at;

DROP INDEX IF EXISTS idx_sessions_shared_with_client;
ALTER TABLE sessions DROP COLUMN IF EXISTS shared_with_client_at;
