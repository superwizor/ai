-- Reverse 000011_session_name: drop the column. Loses any custom renames
-- the therapist did, but that's expected for a schema rollback.
ALTER TABLE sessions DROP COLUMN IF EXISTS name;
