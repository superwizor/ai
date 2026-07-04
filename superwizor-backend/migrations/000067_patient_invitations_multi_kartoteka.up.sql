-- 000067 — allow inviting the same client to many kartoteki (docs/39 D4).
--
-- uq_invitations_org_email (000035) enforces one invitation per
-- (organization, e-mail) — right for therapist/manager onboarding, but
-- it blocks the supported client scenario: a second kartoteka for the
-- same client needs a second PATIENT invitation with the same e-mail
-- (the first one is already accepted, so the refresh path can't reuse
-- it). Caught live by TestClientPanel_AcceptInvitation_MagicLink.
--
-- Replace the table constraint with a partial unique index that keeps
-- the old guarantee for non-PATIENT roles. PATIENT rows stay bounded
-- by uq_invitations_patient_file_pending (000065): at most one PENDING
-- invitation per kartoteka.

ALTER TABLE invitations DROP CONSTRAINT uq_invitations_org_email;

CREATE UNIQUE INDEX uq_invitations_org_email
    ON invitations (organization_id, email)
    WHERE invited_role <> 'PATIENT';
