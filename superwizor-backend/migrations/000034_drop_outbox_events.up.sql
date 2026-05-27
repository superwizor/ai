-- Drop outbox_events table — superseded by client-cache propagation
-- introduced in Phase C of feat/billing-svc-refactor.
--
-- Background:
--   The original Phase 3 design (docs/16, docs/17 §5) wrote quota.* events
--   into outbox_events from billing-svc handlers, ran an in-process poller
--   that published to Pub/Sub topic billing.outbox, and had a Cloud
--   Function (notification-worker-on-billing) consume them to mirror state
--   into Firestore organization_quota/{org}.
--
--   Flutter previously subscribed to that Firestore doc for the
--   QuotaWarningBanner. Phase C replaces that fan-out with a direct read:
--   clinical-svc.GetMyBillingState() returns the billing.v1.Subscription
--   proto (called from Flutter on cold start), and every Reservation /
--   UsageCommit response now carries `state_after` so the cache updates
--   inline without any out-of-band event delivery.
--
--   With the consumer gone, outbox_events has no readers — billing-svc
--   server.go no longer inserts into it, the poller goroutine is removed
--   from cmd/server/main.go, and the Pub/Sub topic + DLQ + CF are torn
--   down via terragrunt apply.
--
-- One-way migration: there is no .down. The poller code is deleted from
-- the binary, so even if we restored the table the writes never happen.
-- If we ever bring back an outbox we'll add a fresh table with whatever
-- schema fits then.
--
-- See: feat/billing-svc-refactor Phase C plan.

DROP INDEX IF EXISTS idx_outbox_aggregate;
DROP INDEX IF EXISTS idx_outbox_unpublished;
DROP TABLE IF EXISTS outbox_events;
