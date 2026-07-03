DROP INDEX IF EXISTS idx_invitations_allocation_pending;
ALTER TABLE invitations DROP CONSTRAINT IF EXISTS chk_invitations_allocation_by_role;
ALTER TABLE invitations DROP CONSTRAINT IF EXISTS chk_invitations_invitable_role;
ALTER TABLE invitations DROP COLUMN IF EXISTS invited_last_name;
ALTER TABLE invitations DROP COLUMN IF EXISTS invited_first_name;
ALTER TABLE invitations DROP COLUMN IF EXISTS allocation_id;
ALTER TABLE invitations DROP COLUMN IF EXISTS invited_role;
