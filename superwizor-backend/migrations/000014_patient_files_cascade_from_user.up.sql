-- 000014: flip patient_files.patient_id FK from ON DELETE SET NULL
-- (migration 000013) to ON DELETE CASCADE.
--
-- Why: the new DeletePatientUser semantics are "RODO erasure of this
-- patient and ALL their data" — every kartoteka, every session, every
-- transcript, every report referencing this person goes away. SET NULL
-- left orphan kartoteki around, which the therapist UI has no good way
-- to represent ("file for nobody"). CASCADE makes the user row the
-- canonical erasure handle.
--
-- Trickle-down behaviour now:
--   DELETE FROM users WHERE id = <patient> AND role = 'PATIENT'
--      → patient_files rows for this patient (CASCADE 000014)
--          → sessions rows                       (CASCADE 000012)
--              → transcripts rows                (CASCADE 000012)
--                  → transcript_segments         (CASCADE 000007)
--              → reports rows                    (CASCADE 000012)
--                  → hitop_measurements          (CASCADE 000007)
--              → audio_uploads.session_id        (SET NULL 000007)
--              → notification_deliveries.session_id (SET NULL 000012)
--          → audio_uploads.patient_file_id        (CASCADE 000012)
--          → rag_memories                         (CASCADE 000007)
--
-- The clinical-svc.DeletePatientUser handler still pre-fetches session
-- IDs and publishes session.deleted Pub/Sub events for each (Firestore
-- mirror + inbox cleanup), because the cascading DELETE doesn't emit
-- any application-level signal.

ALTER TABLE patient_files DROP CONSTRAINT IF EXISTS patient_files_patient_id_fkey;
ALTER TABLE patient_files
  ADD CONSTRAINT patient_files_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE;
