-- name: CreateSession :one
INSERT INTO sessions (
    therapist_id, patient_file_id, audio_upload_id,
    session_date, session_number, duration_seconds, contact_form
) VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: GetNextSessionNumber :one
SELECT COALESCE(MAX(session_number), 0) + 1 AS next_number
FROM sessions
WHERE patient_file_id = $1 AND deleted_at IS NULL;
