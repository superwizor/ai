DROP INDEX IF EXISTS idx_users_phone_number;

CREATE UNIQUE INDEX idx_users_phone_number ON users(phone_number) 
WHERE phone_number IS NOT NULL 
  AND deleted_at IS NULL 
  AND phone_number != '+48 000-000-000' 
  AND phone_number != '+48000000000'
  AND phone_number != '+48 000 000 000'
  AND phone_number != '+48000000000-dupe';
