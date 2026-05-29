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
-- LATERAL JOINs bring in the therapist's organisation's CURRENT
-- subscription (most-recent ACTIVE/TRIAL/PAST_DUE row) + its plan +
-- the most-recent usage counter for that subscription. All three
-- legs are LEFT-LATERAL — orphan therapists / suspended subs /
-- counter-less subs come back as NULLs without losing the session
-- row.
--
-- ORDER BY supports dynamic sorting via @sort_by + @sort_order. We
-- enumerate the allowlisted columns in two parallel CASE chains
-- (one per direction) because sqlc can't bind a raw ORDER BY
-- column. created_at DESC is the trailing tiebreaker so every sort
-- ends with stable order even when the primary sort column is NULL
-- for many rows.
--
-- The handler requests LIMIT+1 so it can compute has_more without a
-- separate COUNT(*) over the (possibly huge) sessions table.
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
    COALESCE(o.legal_name, '') AS organization_name,
    COALESCE(p.display_name, '') AS subscription_plan_name,
    -- CASE wrappers force sqlc to treat the column as nullable —
    -- without them sqlc inherits the NOT NULL annotation from the
    -- underlying column and Scan blows up when the LATERAL match
    -- returned no row.
    (CASE WHEN sub.id IS NULL THEN NULL ELSE sub.current_period_end END) AS subscription_period_end,
    (CASE WHEN uc.tokens_used IS NULL THEN NULL ELSE uc.tokens_used END) AS subscription_tokens_used
FROM sessions s
JOIN users u ON u.id = s.therapist_id
LEFT JOIN organizations o ON o.id = u.organization_id
LEFT JOIN LATERAL (
    -- Pick the most-recent non-terminal subscription for the
    -- therapist's organisation. Single ACTIVE per ADR-BL-001, but
    -- a TRIAL → ACTIVE upgrade leaves both rows, so order by
    -- current_period_end DESC to land on whichever is current.
    SELECT id, plan_id, current_period_end
      FROM subscriptions
     WHERE organization_id = u.organization_id
       -- subscription_status enum values: see migration 000002. The
       -- trial state is 'TRIALING' (NOT 'TRIAL' — that string isn't
       -- in the enum and Postgres throws "invalid input value for
       -- enum").
       AND status IN ('ACTIVE', 'TRIALING', 'PAST_DUE')
     ORDER BY current_period_end DESC
     LIMIT 1
) sub ON TRUE
LEFT JOIN subscription_plans p ON p.id = sub.plan_id
LEFT JOIN LATERAL (
    -- Most-recent usage_counter row for this subscription. If
    -- there's a billing-cycle rollover overlap we land on the
    -- current one (period_end DESC).
    SELECT tokens_used
      FROM usage_counters
     WHERE subscription_id = sub.id
     ORDER BY period_end DESC
     LIMIT 1
) uc ON TRUE
WHERE s.deleted_at IS NULL
  AND s.created_at >= @start_time::timestamptz
  AND s.created_at <  @end_time::timestamptz
  AND (
        @therapist_filter::text = ''
        OR LOWER(COALESCE(u.first_name,'') || ' ' || COALESCE(u.last_name,'')) LIKE '%' || LOWER(@therapist_filter::text) || '%'
        OR LOWER(COALESCE(u.email,'')) LIKE '%' || LOWER(@therapist_filter::text) || '%'
      )
ORDER BY
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'created_at'        THEN s.created_at         END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'session_date'      THEN s.session_date       END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'duration_seconds'  THEN s.duration_seconds   END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'status'            THEN s.status::text       END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'therapist'         THEN LOWER(COALESCE(u.last_name,'') || ' ' || COALESCE(u.first_name,'')) END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'organization'      THEN LOWER(COALESCE(o.legal_name,''))   END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'plan_name'         THEN LOWER(COALESCE(p.display_name,'')) END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'period_end'        THEN sub.current_period_end             END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'asc' AND @sort_by::text = 'tokens_used'       THEN uc.tokens_used                     END ASC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'created_at'       THEN s.created_at         END DESC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'session_date'     THEN s.session_date       END DESC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'duration_seconds' THEN s.duration_seconds   END DESC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'status'           THEN s.status::text       END DESC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'therapist'        THEN LOWER(COALESCE(u.last_name,'') || ' ' || COALESCE(u.first_name,'')) END DESC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'organization'     THEN LOWER(COALESCE(o.legal_name,''))   END DESC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'plan_name'        THEN LOWER(COALESCE(p.display_name,'')) END DESC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'period_end'       THEN sub.current_period_end             END DESC NULLS LAST,
    CASE WHEN @sort_order::text = 'desc' AND @sort_by::text = 'tokens_used'      THEN uc.tokens_used                     END DESC NULLS LAST,
    s.created_at DESC  -- final tiebreaker for stable ordering
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
