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
