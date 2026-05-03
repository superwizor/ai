-- name: GetTranscriptForRebuild :one
SELECT t.id AS transcript_id, t.session_id, t.language_code
FROM transcripts t
WHERE t.session_id = $1
ORDER BY t.created_at DESC
LIMIT 1;

-- name: ListSegmentsForRebuild :many
SELECT speaker_tag, text_ciphertext, text_encrypted_dek,
       start_offset_ms, end_offset_ms, confidence
FROM transcript_segments
WHERE transcript_id = $1
ORDER BY start_offset_ms;

-- name: UpdateTranscriptBlob :exec
UPDATE transcripts SET
    transcript_ciphertext = $2,
    transcript_encrypted_dek = $3,
    blob_rebuilt_at = now(),
    blob_rebuild_count = blob_rebuild_count + 1
WHERE id = $1;

-- name: UpdateSegmentLabel :exec
UPDATE transcript_segments SET speaker_label = $3
WHERE transcript_id = $1 AND speaker_tag = $2;

-- name: UpdateSessionLabelMapping :exec
UPDATE sessions SET speaker_label_mapping = $2
WHERE id = $1;
