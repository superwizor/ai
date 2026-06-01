-- patient_notes — per-patient free-text notes + action plans (docs/22,
-- migration 000040). Clinical PHI: title/text are envelope-encrypted at
-- the handler layer (cryptobox) and stored as (ciphertext, encrypted_dek)
-- BYTEA blobs, same as transcripts/reports. Authz (the note's
-- patient_file.therapist_id == ctx user) is enforced in the gRPC handler;
-- these queries only filter soft-deleted rows.

-- name: CreatePatientNote :one
-- source_session_id is NULL for FREE_NOTE; set to the seeding session for
-- an ACTION_PLAN. The four blob columns carry the encrypted title+text.
INSERT INTO patient_notes (
  patient_file_id, therapist_id, kind, source_session_id,
  title_ciphertext, title_encrypted_dek,
  text_ciphertext, text_encrypted_dek
) VALUES (
  $1, $2, $3, $4,
  $5, $6,
  $7, $8
)
RETURNING *;

-- name: GetPatientNote :one
-- Single note for authz + update/delete/send. Soft-deleted rows are
-- invisible (treated as 404 by the handler).
SELECT * FROM patient_notes
WHERE id = $1 AND deleted_at IS NULL;

-- name: ListPatientNotesByFile :many
-- All live notes for a kartoteka, newest first. Matches the partial
-- index idx_patient_notes_file (patient_file_id, created_at DESC).
SELECT * FROM patient_notes
WHERE patient_file_id = $1 AND deleted_at IS NULL
ORDER BY created_at DESC;

-- name: UpdatePatientNote :one
-- Replaces the encrypted title+text blobs wholesale (the handler
-- re-encrypts the full plaintext on every edit). bumps updated_at.
UPDATE patient_notes SET
  title_ciphertext    = $2,
  title_encrypted_dek = $3,
  text_ciphertext     = $4,
  text_encrypted_dek  = $5,
  updated_at          = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;

-- name: SoftDeletePatientNote :exec
-- Soft delete — keeps the row for audit, hides it from List/Get. (Hard
-- erasure happens via the patient_files CASCADE on RODO delete.)
UPDATE patient_notes SET deleted_at = now()
WHERE id = $1 AND deleted_at IS NULL;

-- name: MarkPatientNoteSent :one
-- Stamps the action-plan e-mail send. Called after notification-svc
-- confirms delivery. Returns the refreshed row so the handler can
-- re-emit the proto with sent_to_patient_at populated.
UPDATE patient_notes SET
  sent_to_patient_at = now(),
  sent_to_email      = $2,
  updated_at         = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;
