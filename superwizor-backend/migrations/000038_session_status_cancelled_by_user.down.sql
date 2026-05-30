-- No-op: PostgreSQL cannot remove a value from an enum type without
-- recreating the type and rewriting every dependent column/index.
-- Rolling back this migration would require all sessions to be off
-- 'CANCELLED_BY_USER' first; not worth the table rewrite. The value
-- is harmless if unused.
SELECT 1;
