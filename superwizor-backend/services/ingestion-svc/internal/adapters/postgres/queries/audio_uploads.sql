-- name: CreateAudioUpload :one
INSERT INTO audio_uploads (
    therapist_id, patient_file_id, bucket_name, object_path,
    content_type, idempotency_key, client_app_version, client_platform
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: GetAudioUploadByIdempotency :one
SELECT * FROM audio_uploads
WHERE idempotency_key = $1 AND therapist_id = $2;

-- name: GetAudioUpload :one
SELECT * FROM audio_uploads WHERE id = $1;

-- name: UpdateAudioUploadStatus :exec
UPDATE audio_uploads
SET status = $2, error_message = $3, upload_completed_at = now()
WHERE id = $1;

-- name: CompleteAudioUpload :one
UPDATE audio_uploads SET
    status = 'UPLOADED',
    upload_completed_at = now(),
    duration_seconds = $2,
    file_size_bytes = $3,
    chunk_count = $4
WHERE id = $1
RETURNING *;

-- name: MarkAudioUploadFailed :exec
UPDATE audio_uploads SET status = 'FAILED', error_message = $2 WHERE id = $1;

-- name: UpdateAudioUploadAfterConversion :one
-- Rewrites object_path + content_type after the new ConvertAudio RPC
-- transcoded the GCS object (e.g. M4A → FLAC). Touched columns are
-- bucket_name (defensively, in case we ever cross buckets — for now
-- always the same) plus object_path + content_type. status stays at
-- PENDING because conversion happens BEFORE CompleteAudioUpload.
-- See services/ingestion-svc/internal/adapters/grpc/server.go::ConvertAudio.
UPDATE audio_uploads SET
    object_path  = $2,
    content_type = $3,
    bucket_name  = $4
WHERE id = $1
RETURNING *;

-- name: CountAudioChunksByUpload :one
-- Stage 2 of feat/stt-long_audio_support: stt-submit + ConvertAudio
-- both use this to detect "this upload was already chunked" — the
-- COUNT must equal expected_chunk_count for the second call to
-- short-circuit. See chunker.go.
SELECT COUNT(*) FROM audio_chunks WHERE audio_upload_id = $1;

-- name: CreateAudioChunk :exec
-- One audio_chunks row. Wrapped in a single tx by the
-- ConvertAudio handler so partial inserts don't survive a crash.
-- UNIQUE on (audio_upload_id, chunk_index) prevents the
-- concurrent-ConvertAudio race (the pg_advisory_xact_lock in the
-- handler is the primary serialization mechanism).
INSERT INTO audio_chunks (
    audio_upload_id, chunk_index,
    bucket_name, object_path,
    start_offset_ms, seam_offset_ms, end_offset_ms,
    overlap_ms, cut_on_silence
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9);

-- name: DeleteAudioChunksByUpload :exec
-- Used by the recovery path: if a prior ConvertAudio crashed mid-
-- chunking (some rows landed, some didn't), the retry detects
-- partial state, deletes everything, and redoes the split. GCS
-- objects from the partial run are left to OLM 48h.
DELETE FROM audio_chunks WHERE audio_upload_id = $1;
