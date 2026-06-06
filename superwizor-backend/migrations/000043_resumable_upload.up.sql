-- Resumable upload (docs/26) + finalize dedup.
--
-- resumable_session_uri / _expires_at: the GCS resumable session the client
-- PUTs byte-range chunks to (so a ~130-min recording resumes across network
-- drops instead of restarting a 62 MB PUT from zero). Issued server-side at
-- CreateAudioUpload; ~7-day lifetime.
--
-- processed_generation: PR3 finalize dedup. GCS→Pub/Sub OBJECT_FINALIZE
-- delivery is at-least-once; resumable creates the object exactly once but the
-- event can be redelivered. Record the object generation we've processed so a
-- repeat is acked without re-running the pipeline.
ALTER TABLE audio_uploads
    ADD COLUMN resumable_session_uri        TEXT,
    ADD COLUMN resumable_session_expires_at TIMESTAMPTZ,
    ADD COLUMN processed_generation         BIGINT;
