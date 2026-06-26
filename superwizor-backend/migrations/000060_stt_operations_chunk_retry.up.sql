-- fix/stt-per-file-transient-retry
-- (see docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md "Watchdog" + incident
-- 12c76823: chunk_2 lost to a transient Chirp 3 code=13 INTERNAL).
--
-- The watchdog used to mark a session FAILED on ANY per-file Chirp
-- error code. Transient codes (INTERNAL/UNAVAILABLE/...) are now
-- re-submitted as a fresh BatchRecognize instead. Two columns support
-- that bounded re-submit loop:
--
--   retry_count      — how many times this chunk has been re-submitted
--                      after a transient per-file error. Bounds the
--                      loop (max 3) so a permanently-flaky chunk still
--                      fails eventually instead of re-billing forever.
--   source_audio_uri — the gs:// URI of THIS chunk's input audio,
--                      captured at submit time. The watchdog needs it
--                      to re-submit; stt_operations otherwise has no
--                      path back to the audio_chunks row. NULL for rows
--                      written before this migration (those fall back
--                      to the old terminal-FAILED behavior — no
--                      regression, just no auto-recovery).

ALTER TABLE stt_operations
    ADD COLUMN retry_count      INT  NOT NULL DEFAULT 0,
    ADD COLUMN source_audio_uri TEXT NOT NULL DEFAULT '';
