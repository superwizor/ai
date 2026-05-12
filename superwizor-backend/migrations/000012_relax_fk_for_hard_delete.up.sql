-- 000012: relax foreign keys so hard-deleting a session or a patient_file
-- cascades cleanly through every dependent table.
--
-- Why hard delete (and not just soft delete with a flag): RODO/GDPR
-- right-to-erasure mandates physical removal of PHI on request. Hard
-- delete also keeps the index footprint reasonable as the system ages.
--
-- Tables affected (all FKs flipped from RESTRICT or NO ACTION):
--   transcripts.session_id              RESTRICT → CASCADE
--   reports.session_id                  RESTRICT → CASCADE
--   hitop_measurements.session_id       RESTRICT → CASCADE
--   sessions.patient_file_id            RESTRICT → CASCADE
--   audio_uploads.patient_file_id       RESTRICT → CASCADE
--   notification_deliveries.session_id  NO ACTION → SET NULL
--
-- Note: notification_deliveries uses SET NULL rather than CASCADE.
-- Reason: delivery history is an audit/observability artefact that
-- should outlive the session it references. We blank the FK so the
-- row keeps its own metadata (delivery_id, sent_at, fcm_message_id)
-- but no longer points at a deleted session.
--
-- Already-CASCADE FKs (left alone):
--   transcript_segments.transcript_id      CASCADE  (000007)
--   rag_memories.patient_file_id           CASCADE  (000007)
--   hitop_measurements.report_id           CASCADE  (000007)
--
-- Already-SET-NULL FKs (left alone):
--   audio_uploads.session_id               SET NULL (000007)
--   rag_memories.source_session_id         SET NULL (000007)
--   rag_memories.source_report_id          SET NULL (000007)

-- ---------- transcripts.session_id ----------
ALTER TABLE transcripts DROP CONSTRAINT IF EXISTS transcripts_session_id_fkey;
ALTER TABLE transcripts
  ADD CONSTRAINT transcripts_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE;

-- ---------- reports.session_id ----------
ALTER TABLE reports DROP CONSTRAINT IF EXISTS reports_session_id_fkey;
ALTER TABLE reports
  ADD CONSTRAINT reports_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE;

-- ---------- hitop_measurements.session_id ----------
ALTER TABLE hitop_measurements DROP CONSTRAINT IF EXISTS hitop_measurements_session_id_fkey;
ALTER TABLE hitop_measurements
  ADD CONSTRAINT hitop_measurements_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE CASCADE;

-- ---------- sessions.patient_file_id ----------
ALTER TABLE sessions DROP CONSTRAINT IF EXISTS sessions_patient_file_id_fkey;
ALTER TABLE sessions
  ADD CONSTRAINT sessions_patient_file_id_fkey
  FOREIGN KEY (patient_file_id) REFERENCES patient_files(id) ON DELETE CASCADE;

-- ---------- audio_uploads.patient_file_id ----------
ALTER TABLE audio_uploads DROP CONSTRAINT IF EXISTS audio_uploads_patient_file_id_fkey;
ALTER TABLE audio_uploads
  ADD CONSTRAINT audio_uploads_patient_file_id_fkey
  FOREIGN KEY (patient_file_id) REFERENCES patient_files(id) ON DELETE CASCADE;

-- ---------- notification_deliveries.session_id ----------
-- Defaults to NO ACTION on a bare REFERENCES — same effect as RESTRICT
-- under PG semantics. Constraint name in this migration follows the
-- PG convention <table>_<col>_fkey; if the original used a custom name
-- the DROP IF EXISTS no-ops and we'll see the ADD fail loudly.
ALTER TABLE notification_deliveries DROP CONSTRAINT IF EXISTS notification_deliveries_session_id_fkey;
ALTER TABLE notification_deliveries
  ADD CONSTRAINT notification_deliveries_session_id_fkey
  FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE SET NULL;
