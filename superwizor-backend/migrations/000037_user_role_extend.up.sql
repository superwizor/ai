-- Extend user_role enum with two new roles introduced by the web app.
--
-- Reference: docs/18_WEB_APP_DESIGN.md §6.3, R4 (single-role MVP).
--
-- ORG_ADMIN: clinic founders + clinic owners. They manage therapists,
-- billing and org settings but do NOT have therapist powers (no
-- kartoteki, no recording). If a founder also wants to practise,
-- they create a second account under a different email.
--
-- SUPERWIZOR_ADMIN: internal Superwizor team. Access to the
-- /admin/* panel; can block orgs, reset tokens, change plans, edit
-- user records. Every mutation writes audit_events with a required
-- reason.
--
-- Note: ALTER TYPE ADD VALUE cannot run inside a multi-statement
-- transaction with subsequent SELECTs using the new value in some
-- Postgres versions — that's why this migration ships standalone
-- (no other statements). golang-migrate applies each .up.sql file
-- as its own implicit transaction.

ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'ORG_ADMIN';
ALTER TYPE user_role ADD VALUE IF NOT EXISTS 'SUPERWIZOR_ADMIN';
