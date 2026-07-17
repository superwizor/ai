ALTER TABLE invitations
    DROP COLUMN IF EXISTS pairing_code_hash,
    DROP COLUMN IF EXISTS code_attempts,
    DROP COLUMN IF EXISTS revoked_at;
