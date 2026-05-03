-- name: CreateSession :one
INSERT INTO sessions (
    therapist_id,
    patient_file_id,
    audio_upload_id,
    session_date,
    session_number,
    duration_seconds,
    contact_form,
    speaker_label_mapping,
    language_code,
    status
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
) RETURNING *;

-- name: GetSession :one
SELECT * FROM sessions
WHERE id = $1 AND deleted_at IS NULL;

-- name: ListSessionsByPatient :many
SELECT * FROM sessions
WHERE patient_file_id = $1 AND deleted_at IS NULL
ORDER BY session_number DESC;

-- name: UpdateSessionStatus :exec
UPDATE sessions
SET status = $2, status_updated_at = now()
WHERE id = $1 AND deleted_at IS NULL;

-- name: GetTranscriptBySession :one
SELECT * FROM transcripts
WHERE session_id = $1;

-- name: ListTranscriptSegments :many
SELECT * FROM transcript_segments
WHERE transcript_id = $1
ORDER BY start_offset_ms ASC;

-- name: ListReportsBySession :many
SELECT * FROM reports
WHERE session_id = $1
ORDER BY created_at DESC;
