ALTER TABLE stt_operations
    DROP COLUMN IF EXISTS retry_count,
    DROP COLUMN IF EXISTS source_audio_uri;
