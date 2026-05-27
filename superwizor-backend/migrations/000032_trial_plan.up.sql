-- Trial plan tier — new therapists get this automatically on first
-- registration (see identity-svc.CreateUser auto-provisioning logic).
--
-- Semantics: 3 tokens, no auto-renewal (cron skips trial subs).
-- The therapist has to actively upgrade to SOLO / PRO / CLINIC to
-- keep recording sessions after the 3 trial tokens are spent.
--
-- We keep cycle='MONTHLY' on the plan row so the existing
-- subscription_plans schema (NOT NULL on cycle) is satisfied without
-- adding a new billing_cycle variant. The period_end on the actual
-- usage_counter is set to 100 years out by the identity-svc bootstrap
-- code — effectively "no expiry" until upgrade.

-- Add TRIAL to plan_tier enum. ALTER TYPE ADD VALUE cannot run inside
-- a transaction in some Postgres versions; that's fine here because
-- migrations are applied one at a time by golang-migrate.
ALTER TYPE plan_tier ADD VALUE IF NOT EXISTS 'TRIAL';
