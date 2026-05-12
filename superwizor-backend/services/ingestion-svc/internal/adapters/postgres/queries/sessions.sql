-- name: CreateSession :one
-- name is computed at app level (see grpc/server.go) as
--   "<modalities.display_name> <session_number>"
-- and passed in as $9. NULLIF($9::text, '') stores NULL when the
-- caller couldn't resolve the modality — backfill migration 000011
-- + handler still survives, just with a NULL row that the proto
-- mapper emits as "" so Flutter falls back to its default rendering.
INSERT INTO sessions (
    therapist_id, patient_file_id, audio_upload_id,
    session_date, session_number, duration_seconds, contact_form, report_language, name
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NULLIF(sqlc.arg(name_default)::text, ''))
RETURNING *;

-- name: GetNextSessionNumber :one
SELECT COALESCE(MAX(session_number), 0) + 1 AS next_number
FROM sessions
WHERE patient_file_id = $1 AND deleted_at IS NULL;

-- name: GetModalityDisplayNameForPatientFile :one
-- Used by CompleteAudioUpload to compute the initial session.name.
-- Returns the modality's display_name for the patient_file's
-- modality_id. Falls back to '' if the join misses (shouldn't happen
-- since patient_files.modality_id is NOT NULL, but defensive).
SELECT COALESCE(m.display_name, '') AS display_name
FROM patient_files pf
LEFT JOIN modalities m ON m.id = pf.modality_id
WHERE pf.id = $1;
