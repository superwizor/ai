-- Org-admin invitations for new therapists.
--
-- Reference: docs/18_WEB_APP_DESIGN.md §6.2, §9 (full magic-link flow),
-- and §6.5 (single-role MVP — invited users land as role=THERAPIST,
-- never auto-promoted to ORG_ADMIN).
--
-- Token storage:
--   - The URL token is 32 bytes of crypto/rand (256-bit), URL-safe-base64
--     encoded. Sent in the email link only.
--   - PG stores SHA-256(token) — NOT Argon2 (R5: high-entropy random
--     tokens don't need slow KDFs and Argon2 on the accept-invite hot
--     path is a CPU-DoS vector). SHA-256 is fast, irreversible, and
--     safe against a DB leak (an attacker with the hash still can't
--     brute-force a 256-bit secret).
--
-- One row per (org_id, email) pair. A new invite for the same email
-- to the same org collides on the unique constraint — handler decides
-- whether to refresh the token + extend expiry or reject.
--
-- Partial index optimises the AcceptInvitation lookup: we only ever
-- query unaccepted rows, so a partial index keeps it lean.

CREATE TABLE invitations (
    id                UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id   UUID         NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    invited_by_user   UUID         NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    -- VARCHAR(255), not CITEXT, to match the existing users.email type
    -- (the citext extension isn't installed and we don't want to add it
    -- just for one column). The handler lowercases the address before
    -- both INSERT and the AcceptInvitation lookup.
    email             VARCHAR(255) NOT NULL,
    token_hash        BYTEA        NOT NULL,
    expires_at        TIMESTAMPTZ NOT NULL,
    accepted_at       TIMESTAMPTZ,
    accepted_user_id  UUID        REFERENCES users(id) ON DELETE SET NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_invitations_org_email UNIQUE (organization_id, email),

    -- accepted_user_id must be set iff accepted_at is set.
    CONSTRAINT chk_invitations_accept_consistency CHECK (
        (accepted_at IS NULL AND accepted_user_id IS NULL)
        OR (accepted_at IS NOT NULL AND accepted_user_id IS NOT NULL)
    )
);

-- Hot-path lookup: AcceptInvitation hashes the incoming token and
-- searches for an unaccepted, unexpired row. Partial index excludes
-- already-consumed rows.
CREATE INDEX idx_invitations_token_hash
    ON invitations(token_hash)
    WHERE accepted_at IS NULL;

-- Org-admin's ListPendingInvitations view ordering.
CREATE INDEX idx_invitations_org_created
    ON invitations(organization_id, created_at DESC)
    WHERE accepted_at IS NULL;
