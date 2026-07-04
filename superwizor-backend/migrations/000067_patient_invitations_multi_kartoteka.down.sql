-- Restore the 000035 table constraint. Requires no duplicate
-- (organization_id, email) PATIENT rows — delete the extras first so
-- the down is deterministic (keep the newest row per pair).

DROP INDEX IF EXISTS uq_invitations_org_email;

-- (id as tie-breaker: rows minted in one transaction share created_at.)
DELETE FROM invitations i
USING invitations newer
WHERE i.organization_id = newer.organization_id
  AND i.email = newer.email
  AND (i.created_at, i.id) < (newer.created_at, newer.id);

ALTER TABLE invitations
    ADD CONSTRAINT uq_invitations_org_email UNIQUE (organization_id, email);
