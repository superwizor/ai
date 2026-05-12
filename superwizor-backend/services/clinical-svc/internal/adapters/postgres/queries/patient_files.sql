-- name: CreatePatientFile :one
INSERT INTO patient_files (
  therapist_id, modality_id, working_alias,
  process_type, initial_complaint, has_recording_consent
) VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: GetPatientFile :one
SELECT * FROM patient_files
WHERE id = $1 AND deleted_at IS NULL;

-- name: ListPatientFilesByTherapist :many
SELECT * FROM patient_files
WHERE therapist_id = $1 AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: CountPatientFilesByTherapist :one
SELECT COUNT(*) FROM patient_files
WHERE therapist_id = $1 AND deleted_at IS NULL;

-- name: UpdatePatientFile :one
UPDATE patient_files SET
  working_alias = COALESCE(NULLIF($2, ''), working_alias),
  initial_complaint = NULLIF($3, ''),
  private_therapist_notes = NULLIF($4, ''),
  is_process_closed = $5,
  updated_at = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;

-- name: SoftDeletePatientFile :exec
-- Kept for backwards compatibility — old gRPC handlers may still call
-- it. New code (post-000012) uses HardDeletePatientFile to satisfy
-- RODO right-to-erasure.
UPDATE patient_files SET deleted_at = now()
WHERE id = $1 AND therapist_id = $2;

-- name: HardDeletePatientFile :execrows
-- Permanent removal. Migration 000012 added ON DELETE CASCADE on
-- sessions.patient_file_id and audio_uploads.patient_file_id, so all
-- child sessions (and their transcripts/reports/hitop rows via the
-- second-level cascade) get wiped in a single statement.
-- therapist_id predicate is the authz guard at the SQL layer.
-- Returns row count so caller can distinguish 404 from success.
DELETE FROM patient_files WHERE id = $1 AND therapist_id = $2;

-- name: ListSessionIDsForPatientFile :many
-- Pre-fetched BEFORE HardDeletePatientFile runs, so the caller can
-- publish one session.deleted Pub/Sub event per affected session for
-- Firestore + inbox cleanup downstream. After the hard delete the
-- rows are gone and we'd have nothing to publish.
SELECT id FROM sessions WHERE patient_file_id = $1 AND deleted_at IS NULL;
