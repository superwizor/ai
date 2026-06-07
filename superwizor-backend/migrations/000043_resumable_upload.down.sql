ALTER TABLE audio_uploads
    DROP COLUMN IF EXISTS resumable_session_uri,
    DROP COLUMN IF EXISTS resumable_session_expires_at,
    DROP COLUMN IF EXISTS processed_generation;
