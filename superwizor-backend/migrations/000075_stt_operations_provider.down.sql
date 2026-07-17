ALTER TABLE stt_operations
    DROP COLUMN IF EXISTS provider,
    DROP COLUMN IF EXISTS request_id,
    DROP COLUMN IF EXISTS fallback_attempted;
