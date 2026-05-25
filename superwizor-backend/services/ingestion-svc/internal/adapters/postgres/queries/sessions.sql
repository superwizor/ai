-- name: CreateSession :one
-- name is computed at app level (see grpc/server.go) as
--   "<modalities.display_name> <session_number>"
-- and passed in as $9. NULLIF($9::text, '') stores NULL when the
-- caller couldn't resolve the modality — backfill migration 000011
-- + handler still survives, just with a NULL row that the proto
-- mapper emits as "" so Flutter falls back to its default rendering.
--
-- language_code is the AUDIO language of the conversation (what STT
-- recognizes), populated from the paired patient_user.ui_language at
-- create time. Distinct from report_language, which is the desired
-- output language for the AI-generated clinical report. NULLIF on
-- empty input so an unset language stores as NULL (stt-worker then
-- falls back to multi-language auto-detect — preserves
-- pre-feat/llm-optimisation behavior for orphan rows).
INSERT INTO sessions (
    therapist_id, patient_file_id, audio_upload_id,
    session_date, session_number, duration_seconds, contact_form,
    report_language, name, language_code
) VALUES (
    $1, $2, $3, $4, $5, $6, $7,
    $8,
    NULLIF(sqlc.arg(name_default)::text, ''),
    NULLIF(sqlc.arg(language_code)::text, '')
)
RETURNING *;

-- name: GetNextSessionNumber :one
SELECT COALESCE(MAX(session_number), 0) + 1 AS next_number
FROM sessions
WHERE patient_file_id = $1 AND deleted_at IS NULL;

-- name: GetSessionByAudioUploadID :one
-- Idempotent-retry helper for CompleteAudioUpload (migration 000024
-- adds ux_sessions_audio_upload_id partial UNIQUE INDEX). When
-- CreateSession hits 23505, the handler looks up the existing row
-- via this query and proceeds with that session instead of
-- creating a duplicate.
SELECT * FROM sessions
WHERE audio_upload_id = $1
  AND deleted_at IS NULL
LIMIT 1;

-- name: CreateSessionPendingUpload :one
-- Option E (2026-05-25, migration 000025): session row created
-- at CreateAudioUpload time, in PENDING_UPLOAD status. The
-- linked audio_uploads row is INSERTed in the same transaction
-- right after. CompleteAudioUpload later flips status to
-- 'CREATED' once ffprobe + chunking + publish succeed.
--
-- audio_upload_id is left NULL initially; the audio_uploads
-- INSERT happens in the same transaction and uses the returned
-- session.id. The full circular link (sessions ↔ audio_uploads)
-- is closed when CompleteAudioUpload sets sessions.status =
-- 'CREATED' — by then both columns are populated.
INSERT INTO sessions (
    therapist_id, patient_file_id, audio_upload_id,
    session_date, session_number, duration_seconds, contact_form,
    report_language, name, language_code, status
) VALUES (
    $1, $2, NULL, $3, $4, $5, $6,
    $7,
    NULLIF(sqlc.arg(name_default)::text, ''),
    NULLIF(sqlc.arg(language_code)::text, ''),
    'PENDING_UPLOAD'
)
RETURNING *;

-- name: UpdateSessionStatus :exec
-- Option E (2026-05-25): used by CompleteAudioUpload to flip
-- PENDING_UPLOAD → CREATED once the audio is confirmed and
-- chunking is done. Used by the orphan-cleanup job too (set to
-- FAILED before cascade-delete).
UPDATE sessions SET status = $2 WHERE id = $1;

-- name: UpdateSessionDuration :one
-- Option E (2026-05-25): sessions.duration_seconds is NULL at
-- CreateAudioUpload time (we don't know it until the upload
-- completes + ffprobe runs). CompleteAudioUpload calls this with
-- the client-provided OR ffprobe-resolved actual duration.
UPDATE sessions SET duration_seconds = $2 WHERE id = $1
RETURNING *;

-- name: SetSessionAudioUploadID :exec
-- Option E (2026-05-25): closes the circular link
-- sessions.audio_upload_id → audio_uploads.id once the
-- audio_uploads row has been INSERTed. Called inside the
-- CreateAudioUpload tx right after the audio_uploads INSERT.
UPDATE sessions SET audio_upload_id = $2 WHERE id = $1;

-- name: GetSessionDefaultsForPatientFile :one
-- Used by CompleteAudioUpload to compute the initial session.name
-- (from modality display_name) AND the session.language_code (from
-- the paired patient_user's ui_language). Single round-trip vs two
-- separate queries.
--
-- Falls back to '' on either column if the join misses:
--   - display_name='' → session.name stored as NULL → Flutter renders default
--   - patient_language='' → stt-worker falls back to multi-language
--     auto-detect (preserves pre-feat/llm-optimisation behavior)
--
-- The patient-user LEFT JOIN guards against patient_files rows that
-- lack a patient_id (orphan rows pre-migration 000014, or after a
-- DeletePatientUser left an orphan before the CASCADE fix).
SELECT
  COALESCE(m.display_name, '')                    AS display_name,
  COALESCE(NULLIF(u.ui_language, ''), '')::text   AS patient_language
FROM patient_files pf
LEFT JOIN modalities m ON m.id = pf.modality_id
LEFT JOIN users u ON u.id = pf.patient_id AND u.role = 'PATIENT' AND u.deleted_at IS NULL
WHERE pf.id = $1;
