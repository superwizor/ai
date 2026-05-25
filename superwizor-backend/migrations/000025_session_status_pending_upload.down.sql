-- 000025 down: Postgres cannot remove enum values without
-- recreating the type. Pinning this no-op so golang-migrate has a
-- DOWN target; rollback path is: rename type, recreate without
-- PENDING_UPLOAD, copy across (operator-managed if ever needed).
-- The forward migration is non-destructive so there's no automated
-- rollback need in normal operation.

SELECT 1;
