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
INSERT INTO users (role, first_name, last_name, ui_language)
VALUES ('PATIENT', $1, $2, $3)
RETURNING id;

-- name: GetPatientUser :one
SELECT id, first_name, last_name, ui_language
FROM users
WHERE id = $1 AND role = 'PATIENT' AND deleted_at IS NULL;

-- name: UpdatePatientUser :one
-- COALESCE/NULLIF pattern: empty string from the caller means "leave
-- this field alone". Concrete value (even a single character) replaces
-- the column. Returns the refreshed row so the handler can re-emit the
-- PatientFile proto with fresh user fields.
UPDATE users SET
  first_name  = COALESCE(NULLIF(sqlc.arg(first_name)::text, ''), first_name),
  last_name   = COALESCE(NULLIF(sqlc.arg(last_name)::text, ''), last_name),
  ui_language = COALESCE(NULLIF(sqlc.arg(language_code)::text, ''), ui_language)
WHERE id = sqlc.arg(id) AND role = 'PATIENT' AND deleted_at IS NULL
RETURNING id, first_name, last_name, ui_language;

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
