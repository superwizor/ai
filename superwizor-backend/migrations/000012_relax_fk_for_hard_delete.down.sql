-- Reverse 000012: restore the RESTRICT/NO ACTION FK semantics.
-- Note: rolling back AFTER any hard delete has run is meaningless —
-- the dependent rows are already gone. This is for forward-flip-back
-- safety during the deploy itself.

-- ---------- transcripts.session_id ----------
ALTER TABLE transcripts DROP CONSTRAINT IF EXISTS transcripts_session_id_fkey;
ALTER TABLE transcripts
  ADD CONSTRAINT transcripts_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE RESTRICT;

-- ---------- reports.session_id ----------
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_session_id_fkey;
ALTER TABLE reports
  ADD CONSTRAINT reports_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE RESTRICT;

-- ---------- hitop_measurements.session_id ----------
ALTER TABLE hitop_measurements DROP CONSTRAINT IF EXISTS hitop_measurements_session_id_fkey;
ALTER TABLE hitop_measurements
  ADD CONSTRAINT hitop_measurements_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE RESTRICT;

-- ---------- sessions.patient_file_id ----------
ALTER TABLE sessions DROP CONSTRAINT IF EXISTS sessions_patient_file_id_fkey;
ALTER TABLE sessions
  ADD CONSTRAINT sessions_patient_file_id_fkey
  FOREIGN KEY (patient_file_id) REFERENCES patient_files(id) ON DELETE RESTRICT;

-- ---------- audio_uploads.patient_file_id ----------
ALTER TABLE audio_uploads DROP CONSTRAINT IF EXISTS audio_uploads_patient_file_id_fkey;
ALTER TABLE audio_uploads
  ADD CONSTRAINT audio_uploads_patient_file_id_fkey
  FOREIGN KEY (patient_file_id) REFERENCES patient_files(id) ON DELETE RESTRICT;

-- ---------- notification_deliveries.session_id ----------
ALTER TABLE notification_deliveries DROP CONSTRAINT IF EXISTS notification_deliveries_session_id_fkey;
ALTER TABLE notification_deliveries
  ADD CONSTRAINT notification_deliveries_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES sessions(id);
