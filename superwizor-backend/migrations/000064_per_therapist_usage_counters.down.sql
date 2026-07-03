-- NOTE: recreating the original UNIQUE(subscription_id, period_start)
-- fails if per-therapist counters were already created — delete them
-- first (they are derived state, rebuildable from allocations).
ALTER TABLE pending_reservations DROP COLUMN IF EXISTS therapist_id;

DROP INDEX IF EXISTS idx_usage_counters_therapist_active;
DROP INDEX IF EXISTS uq_usage_counters_therapist_period;
DROP INDEX IF EXISTS uq_usage_counters_org_period;

DELETE FROM usage_counters WHERE therapist_id IS NOT NULL;
ALTER TABLE usage_counters DROP COLUMN IF EXISTS therapist_id;

ALTER TABLE usage_counters
  ADD CONSTRAINT usage_counters_subscription_id_period_start_key
  UNIQUE (subscription_id, period_start);
