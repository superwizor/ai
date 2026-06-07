-- name: GetPatientNotesForExport :many
SELECT * FROM patient_notes
WHERE patient_file_id = $1 AND deleted_at IS NULL
ORDER BY created_at DESC;

-- name: GetSessionsForExport :many
SELECT * FROM sessions
WHERE patient_file_id = $1 AND deleted_at IS NULL
ORDER BY session_number ASC;

-- name: SoftDeletePatientFileForDSAR :execrows
UPDATE patient_files
SET deleted_at = now(), updated_at = now()
WHERE id = $1 AND therapist_id = $2 AND deleted_at IS NULL;

-- name: SoftDeleteSessionsForDSAR :exec
UPDATE sessions
SET deleted_at = now(), updated_at = now()
WHERE patient_file_id = $1 AND deleted_at IS NULL;

-- name: SoftDeletePatientNotesForDSAR :exec
UPDATE patient_notes
SET deleted_at = now(), updated_at = now()
WHERE patient_file_id = $1 AND deleted_at IS NULL;

-- name: SoftDeletePatientUserForDSAR :execrows
UPDATE users
SET deleted_at = now()
WHERE id = $1 AND role = 'PATIENT' AND deleted_at IS NULL;
