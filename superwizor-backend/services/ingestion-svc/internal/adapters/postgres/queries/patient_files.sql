-- name: GetPatientFileTherapist :one
-- Ownership lookup for the ingestion auth guard (SECURITY #1).
-- CreateAudioUpload derives the therapist from the validated Firebase
-- token and must reject a caller who passes another therapist's
-- patient_file_id. A soft-deleted file (deleted_at IS NOT NULL) still
-- returns its owner — so "deleted" can't be used to bypass the check.
SELECT therapist_id
FROM patient_files
WHERE id = $1;
