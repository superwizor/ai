-- Down: drafts lose their distinction and revert to send-on-create
-- semantics (they become visible to the therapist — acceptable for a
-- rollback; the alternative, deleting drafts, would destroy client
-- content).

ALTER TABLE patient_notes DROP COLUMN sent_to_therapist_at;
