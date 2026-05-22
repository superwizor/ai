-- Reverse of 000021_stt_operations.up.sql.

ALTER TABLE transcripts
    DROP CONSTRAINT IF EXISTS transcripts_session_id_key;

DROP INDEX IF EXISTS idx_stt_operations_pending;

DROP TABLE IF EXISTS stt_operations;
