-- docs/39 PR13 — client-scoped "hide from my panel".
--
-- The client panel lets a client remove a therapist-shared item (a session
-- or a therapist note) from THEIR OWN view without touching the therapist's
-- data. This is distinct from un-sharing (therapist-controlled,
-- shared_with_client_at) and from hard-deleting the client's own notes.
--
-- A non-null client_hidden_at means "the client dismissed this from their
-- panel". Only the Client* read queries filter on it; therapist-facing
-- queries ignore the column entirely.
ALTER TABLE sessions      ADD COLUMN client_hidden_at TIMESTAMPTZ;
ALTER TABLE patient_notes ADD COLUMN client_hidden_at TIMESTAMPTZ;
