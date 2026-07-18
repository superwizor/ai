-- Patient user CRUD — operates on rows in `users` with role='PATIENT'.
-- Created/edited from clinical-svc.CreatePatientFile + UpdatePatientUser
-- + DeletePatientUser handlers. The therapist-side ownership check
-- happens at the handler layer (patient_files.therapist_id == ctx user);
-- queries here filter only by role to defend against accidentally
-- mutating a non-patient row.

-- name: CreatePatientUser :one
-- Inserts a fresh PATIENT row. firebase_uid + email stay NULL (patient
-- has no account yet); the partial CHECK constraints in migration 000013
-- allow that for role='PATIENT'.
--
-- first_name/last_name are deliberately blank (docs/43 §4: the client's
-- only direct identifier is the e-mail; the kartoteka identifies the
-- client by patient_files.working_alias). Columns stay NOT NULL for the
-- therapist rows, so we write ''.
INSERT INTO users (role, first_name, last_name, ui_language)
VALUES ('PATIENT', '', '', $1)
RETURNING id;

-- name: GetPatientUser :one
SELECT id, ui_language
FROM users
WHERE id = $1 AND role = 'PATIENT' AND deleted_at IS NULL;

-- name: UpdatePatientUser :one
-- COALESCE/NULLIF pattern: empty string from the caller means "leave
-- this field alone". Names are no longer editable here (docs/43 §4 —
-- the kartoteka's identifier is working_alias, edited via
-- UpdatePatientFile); only the patient's UI language remains.
UPDATE users SET
  ui_language = COALESCE(NULLIF(sqlc.arg(language_code)::text, ''), ui_language)
WHERE id = sqlc.arg(id) AND role = 'PATIENT' AND deleted_at IS NULL
RETURNING id, ui_language;

-- name: DeletePatientUser :execrows
-- Hard delete. patient_files.patient_id FK is SET NULL (migration
-- 000013) so any kartoteka referencing this row gets its patient_id
-- cleared automatically. Returns rows-affected so the handler can
-- distinguish "not found / not a patient" from success.
DELETE FROM users WHERE id = $1 AND role = 'PATIENT';

-- name: GetTherapistUILanguage :one
-- Used by CreatePatientFile to default the new patient's ui_language
-- when the caller didn't pass one. Returns '' if the therapist row is
-- somehow missing (shouldn't happen — auth interceptor would reject).
SELECT COALESCE(ui_language, '') AS ui_language
FROM users
WHERE id = $1;

-- name: ListSessionIDsForPatient :many
-- Pre-fetched before DeletePatientUser runs so the handler can fan
-- out one session.deleted Pub/Sub event per session that will be
-- cascade-deleted by the user row going away (migration 000014).
-- JOIN-based because sessions don't reference users directly — they
-- hang off patient_files which hang off users.
-- After the cascade the rows are gone; we'd have nothing to publish
-- from a post-delete query.
SELECT s.id
FROM sessions s
JOIN patient_files pf ON pf.id = s.patient_file_id
WHERE pf.patient_id = $1 AND pf.deleted_at IS NULL AND s.deleted_at IS NULL;
