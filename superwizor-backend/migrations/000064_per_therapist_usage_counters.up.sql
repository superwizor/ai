-- 000064: Per-therapist token counters (docs/38 §3, billing model).
--
-- Design decision (2026-07-03): each seat (therapist) gets its OWN
-- usage_counter with tokens_limit = tokens_per_period of their seat's
-- plan, renewed per that plan's cycle. Enforcement is per-therapist:
-- a therapist who exhausts their counter is blocked even if colleagues
-- have tokens left. Supersedes the earlier shared-org-counter model.
--
-- Backward compatibility: therapist_id IS NULL = org-level counter.
-- All existing rows stay NULL and keep working exactly as before —
-- solo therapists and orgs without seat allocations are untouched.
-- ReserveCredit resolution order (billing-svc): therapist-scoped
-- counter first, org-level NULL counter as fallback.
--
-- pending_reservations grows therapist_id so ReleaseCredit / the
-- expiry cron / CommitUsage can credit tokens back to the SAME
-- therapist's counter the reservation debited (NULL = org-level,
-- matching the counter that was locked at reserve time).

ALTER TABLE usage_counters
  ADD COLUMN therapist_id UUID REFERENCES users(id) ON DELETE CASCADE;

COMMENT ON COLUMN usage_counters.therapist_id IS
    'NULL = org-level counter (legacy / solo). Non-NULL = per-seat counter '
    'for this therapist; tokens_limit comes from the seat''s plan '
    '(docs/38 §3, per-therapist enforcement).';

-- The old table constraint allowed exactly one counter per subscription
-- per period — with per-seat counters there is one per (sub, therapist,
-- period) plus at most one org-level row. Two partial unique indexes
-- express that (avoids relying on PG15 NULLS NOT DISTINCT).
ALTER TABLE usage_counters
  DROP CONSTRAINT usage_counters_subscription_id_period_start_key;

CREATE UNIQUE INDEX uq_usage_counters_org_period
    ON usage_counters(subscription_id, period_start)
    WHERE therapist_id IS NULL;

CREATE UNIQUE INDEX uq_usage_counters_therapist_period
    ON usage_counters(subscription_id, therapist_id, period_start)
    WHERE therapist_id IS NOT NULL;

-- Hot path: LockActiveCounter by (subscription, therapist, now() in period).
CREATE INDEX idx_usage_counters_therapist_active
    ON usage_counters(subscription_id, therapist_id, period_start, period_end)
    WHERE therapist_id IS NOT NULL;

ALTER TABLE pending_reservations
  ADD COLUMN therapist_id UUID REFERENCES users(id) ON DELETE SET NULL;

COMMENT ON COLUMN pending_reservations.therapist_id IS
    'Therapist whose counter was debited at ReserveCredit (NULL = the '
    'org-level counter). Release/expiry/commit must credit the same scope. '
    'Also the per-therapist usage attribution source for org analytics.';
