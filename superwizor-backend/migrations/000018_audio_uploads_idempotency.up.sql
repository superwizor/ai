-- Fix two bugs on audio_uploads.idempotency_key from migration 000007.
--
-- Bug 1 — column-level UNIQUE was GLOBAL (cross-therapist):
--   `idempotency_key VARCHAR(128) UNIQUE`
-- Therapist A picking key "abc-123" permanently locked that string
-- out for therapist B. Clients pick keys to be unique within their
-- request space; they have no global namespace coordination.
--
-- Bug 2 — the ingestion-svc handler's lookup query already filters
-- by `(therapist_id, idempotency_key)` (GetAudioUploadByIdempotency),
-- so the constraint and the query were inconsistent.
--
-- Fix: replace the global UNIQUE with a partial unique index keyed
-- on (therapist_id, idempotency_key). Per-therapist scoping. Partial
-- on `idempotency_key IS NOT NULL` so legacy rows (key NULL) coexist
-- freely, mirroring the same convention used in migration 000017 for
-- patient_files.

-- Drop the old global UNIQUE. The constraint name on the auto-created
-- column-level UNIQUE is conventionally `<table>_<col>_key`.
ALTER TABLE audio_uploads
  DROP CONSTRAINT IF EXISTS audio_uploads_idempotency_key_key;

CREATE UNIQUE INDEX ux_audio_uploads_idempotency
  ON audio_uploads (therapist_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

COMMENT ON COLUMN audio_uploads.idempotency_key IS
  'Client-supplied retry key. Same (therapist_id, idempotency_key) returns the first row created with that key — payload differences are ignored (lenient mode). NULL = opt-out.';
