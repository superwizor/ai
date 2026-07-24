DROP INDEX IF EXISTS idx_users_first_app_login;
ALTER TABLE users DROP COLUMN IF EXISTS first_app_login_at;
