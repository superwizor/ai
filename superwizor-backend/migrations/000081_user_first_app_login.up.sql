-- Migration 000081: first_app_login_at column on users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS first_app_login_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_users_first_app_login ON users(first_app_login_at) WHERE deleted_at IS NULL;
