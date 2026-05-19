-- Add idempotency_key support to clinical.v1.CreatePatientFile.
--
-- Until now the handler silently ignored the proto field; client
-- retries created duplicate rows that only failed at the
-- `(therapist_id, working_alias) WHERE deleted_at IS NULL` partial
-- unique index added in 000013. That index masked the real bug:
-- retries with the SAME alias surfaced as `AlreadyExists`; retries
-- with a DIFFERENT alias (rare but legal) silently double-created.
--
-- This migration adds a per-resource idempotency key. Lenient mode:
-- same (therapist_id, idempotency_key) returns the first call's row
-- regardless of payload — no hashing, no TTL. Empty/NULL key opts
-- out (preserves existing client behavior).
--
-- Index is PARTIAL on (deleted_at IS NULL) so a hard-deleted
-- kartoteka frees its key for re-use, matching the
-- `(therapist_id, working_alias)` partial index added in 000013 §3.

ALTER TABLE patient_files
  ADD COLUMN idempotency_key VARCHAR(128);

CREATE UNIQUE INDEX ux_patient_files_idempotency
  ON patient_files (therapist_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL AND deleted_at IS NULL;

COMMENT ON COLUMN patient_files.idempotency_key IS
  'Client-supplied retry key. Same (therapist_id, idempotency_key) returns the first row created with that key — payload differences are ignored (lenient mode). NULL = opt-out (legacy clients).';
