-- docs/39_DEEPGRAM_STT_MIGRATION.md — multi-provider STT.
--
-- provider           discriminates the engine that owns the row
--                    ('chirp' | 'deepgram'); every pre-existing row is
--                    Chirp by construction, hence the DEFAULT backfill.
-- request_id         the external request handle (Deepgram
--                    metadata.request_id) for support/audit lookups on
--                    the provider side. NULL for Chirp rows (they key on
--                    operation_id instead).
-- fallback_attempted marks a row that was failed over deepgram→chirp by
--                    the watchdog / takeover path, so the failover runs
--                    AT MOST once per chunk and can't ping-pong.
--                    (Deviation from the docs/39 sketch which proposed a
--                    self-referencing fallback_from UUID — a boolean is
--                    sufficient because the failover overwrites the row
--                    in place and the prior request_id is preserved in
--                    finalize_error for audit.)
ALTER TABLE stt_operations
    ADD COLUMN provider           VARCHAR(20) NOT NULL DEFAULT 'chirp',
    ADD COLUMN request_id         TEXT,
    ADD COLUMN fallback_attempted BOOLEAN NOT NULL DEFAULT FALSE;
