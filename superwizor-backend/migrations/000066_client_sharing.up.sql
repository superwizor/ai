-- 000066: Explicit sharing with the client panel + client notes
-- (docs/39 §3, decisions D2/D6).
--
-- Default-deny: the client sees ONLY rows the therapist explicitly
-- shared. Sharing DELIVERS to the panel — the content e-mail flow
-- (ACTION_PLAN body in the mail) is superseded by a PHI-free
-- notification; content lives encrypted in the DB only (D6).

-- Sessions: shared ⇒ the client may read metadata + transcript.
ALTER TABLE sessions ADD COLUMN shared_with_client_at TIMESTAMPTZ;

COMMENT ON COLUMN sessions.shared_with_client_at IS
    'Set when the therapist shares this session (incl. transcript) '
    'with the client panel (docs/39 D2). NULL = not visible to the '
    'client. Unshare = back to NULL.';

CREATE INDEX idx_sessions_shared_with_client
    ON sessions(patient_file_id)
    WHERE shared_with_client_at IS NOT NULL AND deleted_at IS NULL;

-- Notes: sharing marker + client authorship.
ALTER TABLE patient_notes ADD COLUMN shared_with_client_at TIMESTAMPTZ;
ALTER TABLE patient_notes ADD COLUMN author_role user_role NOT NULL DEFAULT 'THERAPIST';
ALTER TABLE patient_notes ADD COLUMN read_by_therapist_at TIMESTAMPTZ;
ALTER TABLE patient_notes ADD COLUMN read_by_client_at TIMESTAMPTZ;

COMMENT ON COLUMN patient_notes.author_role IS
    'THERAPIST for FREE_NOTE/ACTION_PLAN; PATIENT for CLIENT_NOTE '
    '(docs/39). therapist_id stays NOT NULL as the counterparty.';

-- CLIENT_NOTE joins the kind enum-check. The original CHECK was
-- inline, so it carries the default name.
ALTER TABLE patient_notes DROP CONSTRAINT patient_notes_kind_check;
ALTER TABLE patient_notes ADD CONSTRAINT patient_notes_kind_check
  CHECK (kind IN ('FREE_NOTE', 'ACTION_PLAN', 'CLIENT_NOTE'));

-- Author/kind coherence: client notes are authored by the patient and
-- are visible to the client by definition; therapist kinds by the
-- therapist.
ALTER TABLE patient_notes ADD CONSTRAINT chk_patient_notes_author
  CHECK (
      (kind = 'CLIENT_NOTE' AND author_role = 'PATIENT')
   OR (kind <> 'CLIENT_NOTE' AND author_role = 'THERAPIST')
  );

-- Backfill (D6): action plans already e-mailed to the patient count as
-- shared — the panel shows the same content the inbox already has.
UPDATE patient_notes
   SET shared_with_client_at = sent_to_patient_at
 WHERE sent_to_patient_at IS NOT NULL
   AND shared_with_client_at IS NULL;

-- Client-panel listing path.
CREATE INDEX idx_patient_notes_client_visible
    ON patient_notes(patient_file_id)
    WHERE shared_with_client_at IS NOT NULL OR kind = 'CLIENT_NOTE';
