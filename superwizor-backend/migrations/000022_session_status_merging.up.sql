-- Stage 1 of feat/stt-long_audio_support.
--
-- Add MERGING to session_status enum. Used by stt-finalize's
-- acquireMergeLock() to serialize multi-chunk merges (Stage 2) AND
-- single-chunk finalize attempts that race on Pub/Sub at-least-once
-- redelivery (Stage 1).
--
-- The flip TRANSCRIBING → MERGING happens inside the FOR UPDATE
-- transaction; once committed, only ONE finalize invocation owns
-- the merge work. The mergeAndPersist body advances to ANALYZING
-- on success or reverts to TRANSCRIBING on transient failure.
--
-- Why an enum value (not a separate boolean column):
--   - One source of truth for session lifecycle state.
--   - SELECT status FROM sessions WHERE id=$1 FOR UPDATE serializes
--     correctly without joining a separate lock table.
--   - notification-svc dashboards / Firestore mirror can render
--     MERGING as a transient "still processing" state if they care.
--
-- See docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md mergeAndPersist
-- section.

ALTER TYPE session_status ADD VALUE IF NOT EXISTS 'MERGING'
    AFTER 'TRANSCRIBING';
