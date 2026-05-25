-- Stage 1 of feat/stt-long_audio_support
-- (see docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md).
--
-- Splits stt-worker into stt-submit + stt-finalize via GCS callback.
-- Submit writes a row here per BatchRecognize call; finalize flips
-- finalized_at when Chirp's output object lands and the merge runs.
--
-- Stage 1: always one row per session (chunk_index = 0).
-- Stage 2 (forthcoming): multiple rows when audio > 19 min was
-- split server-side; chunk_index 0..N-1.

CREATE TABLE stt_operations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id      UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,

    -- Index in the chunk sequence for this session. 0 means
    -- "the only chunk" in Stage 1. UNIQUE prevents the
    -- redelivery race (same chunk submitted twice).
    chunk_index     INT  NOT NULL DEFAULT 0,
    -- Total chunks expected for this session. stt-finalize uses
    -- COUNT(*) WHERE finalized_at IS NULL but also needs the
    -- denominator to be sure all rows landed (a row might be
    -- missing from a failed submit). Set at submit time.
    chunk_count     INT  NOT NULL DEFAULT 1,

    -- Offset of THIS chunk's start in the ORIGINAL audio's
    -- timeline. Used by stt-finalize to re-relativize per-chunk
    -- word offsets when merging. Stage 1: always 0.
    start_offset_ms BIGINT NOT NULL DEFAULT 0,

    -- Chirp operation handle. Useful for the watchdog (poll the
    -- Operations API when finalize hasn't fired in 30 min).
    operation_id    TEXT NOT NULL,
    -- gs://bucket/path/ prefix where Chirp wrote the result file.
    gcs_output_uri  TEXT NOT NULL,

    -- Submit-time config snapshot. stt-finalize trusts these
    -- over re-reading env vars (which might have flipped
    -- between submit and finalize).
    language_code            TEXT NOT NULL DEFAULT '',
    used_native_diarization  BOOLEAN NOT NULL DEFAULT FALSE,

    submitted_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    finalized_at    TIMESTAMPTZ,
    -- If finalize classified the result as terminal failure
    -- (e.g. Chirp file-level error), the reason ends up here
    -- for ops inspection. NULL on success.
    finalize_error  TEXT,

    UNIQUE (session_id, chunk_index)
);

-- Watchdog query: WHERE submitted_at < now() - interval '30 minutes'
-- AND finalized_at IS NULL.
CREATE INDEX idx_stt_operations_pending
    ON stt_operations(submitted_at)
    WHERE finalized_at IS NULL;

-- transcripts(session_id) UNIQUE — supports crash-recovery in
-- stt-finalize's mergeAndPersist. If persistTranscript committed
-- but the worker crashed before publishTranscriptCompleted, the
-- retry hits 23505 instead of inserting a duplicate transcripts
-- row. Finalize then fetches the existing row's id and proceeds
-- to publish.
--
-- Pre-condition: the existing schema has at most one transcripts
-- row per session today (assumed invariant from the original
-- design; no migration ever violated it). Adding the constraint
-- now bakes the invariant in for stt-finalize's idempotent path.
ALTER TABLE transcripts
    ADD CONSTRAINT transcripts_session_id_key UNIQUE (session_id);
