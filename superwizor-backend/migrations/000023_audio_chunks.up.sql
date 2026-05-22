-- Stage 2 of feat/stt-long_audio_support
-- (see docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md Stage 2).
--
-- Holds the per-chunk metadata produced when ingestion-svc splits an
-- audio_upload that's > 19 min (Chirp 3's hard limit with word-level
-- timestamps enabled).
--
-- One row per FLAC chunk that ingestion-svc's ffmpeg pipeline
-- produces. Empty for uploads ≤ 19 min — stt-submit synthesizes a
-- single virtual chunk in that case (existing Stage 1 path).

CREATE TABLE audio_chunks (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    audio_upload_id UUID NOT NULL REFERENCES audio_uploads(id) ON DELETE CASCADE,

    -- 0-based chunk index. UNIQUE per upload prevents a re-running
    -- ingestion-svc split (e.g. retry after crash) from creating
    -- duplicate chunk rows. The pg_advisory_xact_lock on
    -- audio_upload_id in ConvertAudio's chunking path is the
    -- belt-and-suspenders pair to this UNIQUE.
    chunk_index     INT  NOT NULL,

    -- GCS object path of THIS chunk's FLAC.
    bucket_name     TEXT NOT NULL,
    object_path     TEXT NOT NULL,

    -- Offsets into the ORIGINAL audio's timeline:
    --   start_offset_ms  — physical start of this chunk's audio
    --                      (where ffmpeg actually cut)
    --   seam_offset_ms   — logical cut point shared with chunk_{i+1}
    --                      (chunk_{i+1}.start_offset_ms ≤ seam ≤
    --                       chunk_i.end_offset_ms; overlap_ms wide)
    --   end_offset_ms    — physical end of this chunk's audio
    --
    -- For chunk_index=0: start_offset_ms = 0, seam_offset_ms = the
    -- cut point shared with chunk 1, end_offset_ms = seam (no
    -- overlap behind it).
    -- For chunk_index=N-1 (last): start = chunk_{N-2}.seam - overlap,
    -- seam = end_offset_ms, end = source duration.
    start_offset_ms BIGINT NOT NULL,
    seam_offset_ms  BIGINT NOT NULL,
    end_offset_ms   BIGINT NOT NULL,

    -- Width (ms) of the overlap with the PRIOR chunk. 0 for chunk 0.
    -- Stored per-row so the cross-chunk alignment algorithm can
    -- replay against the exact overlap width that produced any
    -- given session — the alignment constants can move between
    -- runs without breaking existing audio_chunks rows.
    overlap_ms      INT  NOT NULL DEFAULT 0,

    -- Did ffmpeg find a real silence at this cut point, or did we
    -- fall back to a hard time-based cut? Pure observability —
    -- alignment quality should be slightly worse for the fallback
    -- case.
    cut_on_silence  BOOLEAN NOT NULL DEFAULT TRUE,

    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (audio_upload_id, chunk_index)
);

-- Hot path: stt-submit reads audio_chunks WHERE audio_upload_id = $1
-- ORDER BY chunk_index. Covered by the UNIQUE constraint's
-- automatic index, but adding an explicit index documents the
-- query pattern.
CREATE INDEX idx_audio_chunks_upload
    ON audio_chunks(audio_upload_id, chunk_index);
