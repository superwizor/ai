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
    report_language,
    status
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
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

-- name: GetSessionWithDetails :one
SELECT 
    s.id,
    s.therapist_id,
    s.patient_file_id,
    s.audio_upload_id,
    s.session_date,
    s.session_number,
    s.duration_seconds,
    s.contact_form,
    s.speaker_label_mapping,
    s.language_code,
    s.report_language,
    s.status,
    s.status_updated_at,
    s.created_at,
    s.deleted_at,
    t.id AS transcript_id,
    t.session_id AS transcript_session_id,
    r.id AS report_id,
    r.session_id AS report_session_id
FROM sessions s
LEFT JOIN transcripts t ON t.session_id = s.id
LEFT JOIN reports r ON r.session_id = s.id
WHERE s.id = $1 AND s.deleted_at IS NULL;
