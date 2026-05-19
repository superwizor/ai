-- Best-effort revert: drop the partial index and reinstate a global
-- UNIQUE. NOTE: this can FAIL if the data has acquired cross-therapist
-- collisions in the meantime — those would need manual cleanup
-- before re-running the down migration. Production usually doesn't
-- want to downgrade past this point; the up direction is the safe
-- correctness fix.
DROP INDEX IF EXISTS ux_audio_uploads_idempotency;

ALTER TABLE audio_uploads
  ADD CONSTRAINT audio_uploads_idempotency_key_key UNIQUE (idempotency_key);
