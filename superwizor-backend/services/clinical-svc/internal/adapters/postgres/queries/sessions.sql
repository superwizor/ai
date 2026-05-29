-- name: AdminListRecentSessions :many
--
-- Cross-org session activity for /admin/sessions (SUPERWIZOR_ADMIN).
-- Filter window is on sessions.created_at (when the server-side row
-- was created, i.e. when the upload landed) — this matches "recent
-- activity" semantics better than the user-entered session_date.
--
-- The therapist filter is a single substring matched
-- case-insensitively against first_name + last_name + email. Empty
-- string means "no filter".
--
-- ORDER BY created_at DESC + LIMIT/OFFSET pagination. The handler
-- requests LIMIT+1 so it can compute has_more without a separate
-- COUNT(*) over the (possibly huge) sessions table.
SELECT
    s.id,
    s.created_at,
    s.session_date,
    s.duration_seconds,
    s.status::text AS status,
    s.session_number,
    u.id AS therapist_id,
    COALESCE(u.first_name, '') AS therapist_first_name,
    COALESCE(u.last_name,  '') AS therapist_last_name,
    COALESCE(u.email,      '') AS therapist_email,
    COALESCE(u.organization_id::text, '') AS organization_id,
    COALESCE(o.legal_name, '') AS organization_name
FROM sessions s
JOIN users u ON u.id = s.therapist_id
LEFT JOIN organizations o ON o.id = u.organization_id
WHERE s.deleted_at IS NULL
  AND s.created_at >= @start_time::timestamptz
  AND s.created_at <  @end_time::timestamptz
  AND (
        @therapist_filter::text = ''
        OR LOWER(COALESCE(u.first_name,'') || ' ' || COALESCE(u.last_name,'')) LIKE '%' || LOWER(@therapist_filter::text) || '%'
        OR LOWER(COALESCE(u.email,'')) LIKE '%' || LOWER(@therapist_filter::text) || '%'
      )
ORDER BY s.created_at DESC
LIMIT @page_limit::int OFFSET @page_offset::int;

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

-- name: UpdateSessionName :one
-- Rename a session. Caller is responsible for the authz check
-- (session.therapist_id == ctx user). Returns the refreshed row so
-- the gRPC handler can re-emit the proto Session.
UPDATE sessions
SET name = $2, updated_at = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;

-- name: HardDeleteSession :execrows
-- Permanent delete. Migration 000012 added ON DELETE CASCADE on
-- transcripts.session_id, reports.session_id, hitop_measurements.session_id,
-- so dependent rows are removed automatically. notification_deliveries
-- gets SET NULL — delivery history survives, just unbound from session.
-- audio_uploads.session_id is already SET NULL since 000007.
-- The therapist_id predicate is the authz guard at the query level.
-- Returns affected rows so the handler can distinguish "not found /
-- not yours" (0 rows) from successful delete (1 row).
DELETE FROM sessions WHERE id = $1 AND therapist_id = $2;

-- name: GetDefaultSessionName :one
-- Compute the default session.name as production would set it on
-- create. Used by ingestion-svc.CompleteAudioUpload when populating
-- the column for a brand-new session. The COALESCE guards against
-- a missing modality join (defensive — modality_id is NOT NULL on
-- patient_files so this should never fire, but cheap insurance).
SELECT COALESCE(m.display_name, 'Sesja') || ' ' || $2::text AS default_name
FROM patient_files pf
LEFT JOIN modalities m ON m.id = pf.modality_id
WHERE pf.id = $1;

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
