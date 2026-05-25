-- 000024_unique_session_per_audio_upload.up.sql
--
-- Adds a partial UNIQUE INDEX on sessions(audio_upload_id) WHERE
-- audio_upload_id IS NOT NULL.
--
-- Why: ingestion-svc::CompleteAudioUpload is a multi-step handler
-- (ffprobe → chunking → CreateSession → publish). There is NO outer
-- transaction wrapping all phases. If the worker crashes between the
-- ConvertAudio commit and the CreateSession commit — or between
-- CreateSession and the Pub/Sub publish — a retry by Flutter (queue
-- or otherwise) re-enters the handler with the same upload_id and
-- re-runs CreateSession. The existing schema has audio_upload_id as
-- a plain FK with NO uniqueness, so the retry succeeds and creates
-- a DUPLICATE session row pointing at the same audio_uploads row.
-- The first session becomes a permanent orphan (no transcript ever
-- attaches); the second progresses normally; the therapist sees a
-- ghost session in the list.
--
-- The constraint is PARTIAL (`WHERE audio_upload_id IS NOT NULL`)
-- because the column is FK with `ON DELETE SET NULL` (migration
-- 000007 line 45). Cascade-deleted audio_uploads leave sessions
-- with audio_upload_id=NULL — those rows must not collide with each
-- other on the constraint, only with each other on (session_id,
-- audio_upload_id) when both are non-NULL.
--
-- Companion application change: services/ingestion-svc/internal/
-- adapters/grpc/server.go::CompleteAudioUpload, on 23505 against
-- this index, fetches the existing session via the new
-- GetSessionByAudioUploadID query and proceeds idempotently.
--
-- Safety: this migration ABORTS if duplicate audio_upload_ids
-- already exist in the table. Production must be inspected and
-- duplicates resolved before this lands. Staging is currently
-- clean (only a handful of test sessions; no observed retries).

-- 1. Guard: refuse to apply if duplicates already exist. Operators
--    must clean them up manually first — we don't pick which session
--    is the "real" one because both could carry transcript /
--    therapist_report references that need merging by hand.
DO $$
DECLARE
    dup_count INT;
BEGIN
    SELECT COUNT(*) INTO dup_count
    FROM (
        SELECT audio_upload_id
        FROM sessions
        WHERE audio_upload_id IS NOT NULL
        GROUP BY audio_upload_id
        HAVING COUNT(*) > 1
    ) t;

    IF dup_count > 0 THEN
        RAISE EXCEPTION
            'Cannot apply migration 000024: % audio_upload_id values map to >1 session. Run: SELECT audio_upload_id, array_agg(id) FROM sessions WHERE audio_upload_id IS NOT NULL GROUP BY audio_upload_id HAVING COUNT(*) > 1; and resolve before retrying.',
            dup_count;
    END IF;
END $$;

-- 2. The constraint itself.
CREATE UNIQUE INDEX ux_sessions_audio_upload_id
    ON sessions(audio_upload_id)
    WHERE audio_upload_id IS NOT NULL;
