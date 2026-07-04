-- 000068 — client note drafts (docs/39 live-feedback 2026-07-04).
--
-- Until now a CLIENT_NOTE reached the therapist the moment it was
-- created. The client panel now distinguishes:
--   sent_to_therapist_at IS NULL     → private draft, visible ONLY in
--                                      the client panel;
--   sent_to_therapist_at IS NOT NULL → delivered — the therapist's
--                                      ListPatientNotes includes it.
-- Backfill: every pre-existing CLIENT_NOTE was created under
-- send-on-create semantics, so it counts as delivered at creation.

ALTER TABLE patient_notes ADD COLUMN sent_to_therapist_at TIMESTAMPTZ;

UPDATE patient_notes SET sent_to_therapist_at = created_at
WHERE kind = 'CLIENT_NOTE';
