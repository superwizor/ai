DROP TABLE IF EXISTS seat_assignments;
ALTER TABLE users DROP COLUMN IF EXISTS deactivated_at;
ALTER TABLE users DROP COLUMN IF EXISTS is_active;
