-- 000040 — patient_notes + patient_files.patient_email (docs/22)
--
-- patient_notes: per-patient free-text notes and action plans the therapist
-- jots down between sessions. Until now these lived only on-device (Flutter
-- Hive); this moves them server-side so they survive reinstall, sync across
-- devices, and fall under RODO export/erase.
--
-- Notes are clinical free text (PHI) → envelope-encrypted at rest like
-- transcripts/reports: title/text stored as (ciphertext, encrypted_dek) blobs
-- (cryptobox / Cloud KMS). The DB itself is CMEK-encrypted; app-level envelope
-- encryption adds defense-in-depth consistent with reports.
--
-- ON DELETE CASCADE from patient_files means the existing DeletePatientFile /
-- DeletePatientUser RODO fan-out erases a patient's notes automatically.

CREATE TABLE patient_notes (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_file_id     UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    therapist_id        UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,

    -- FREE_NOTE: ad-hoc note. ACTION_PLAN: extracted from a session report and
    -- (optionally) sent to the patient by e-mail.
    kind                TEXT NOT NULL DEFAULT 'FREE_NOTE'
                          CHECK (kind IN ('FREE_NOTE', 'ACTION_PLAN')),
    -- The session whose report seeded an ACTION_PLAN (NULL for FREE_NOTE or if
    -- the source session is later deleted).
    source_session_id   UUID REFERENCES sessions(id) ON DELETE SET NULL,

    -- Envelope-encrypted title + body.
    title_ciphertext        BYTEA NOT NULL,
    title_encrypted_dek     BYTEA NOT NULL,
    text_ciphertext         BYTEA NOT NULL,
    text_encrypted_dek      BYTEA NOT NULL,

    -- Set when an ACTION_PLAN note was e-mailed to the patient.
    sent_to_patient_at  TIMESTAMPTZ,
    sent_to_email       TEXT,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at          TIMESTAMPTZ
);

-- List notes for a patient, newest first (handler filters deleted_at).
CREATE INDEX idx_patient_notes_file
    ON patient_notes (patient_file_id, created_at DESC)
    WHERE deleted_at IS NULL;

-- patient_files.patient_email — where the patient's contact e-mail lives.
-- Nullable because many kartoteki are pseudonymous (patient_id IS NULL, no
-- linked users row). Plaintext, consistent with working_alias / the DB's CMEK
-- at-rest encryption; it's contact PII, not session content.
ALTER TABLE patient_files ADD COLUMN patient_email TEXT;
