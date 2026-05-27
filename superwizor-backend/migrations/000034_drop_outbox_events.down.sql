-- One-way migration. See .up.sql header for rationale.
--
-- We intentionally do NOT recreate outbox_events here — the calling code
-- (poller goroutine, AppendOutboxEvent calls in ReserveCredit / CommitUsage,
-- notification-worker-on-billing CF) has been deleted from the repo, so a
-- restored table would just be inert. If you really need to roll back to
-- the outbox model, revert the Phase C commits in feat/billing-svc-refactor
-- (they recreate the table via 000031) instead of running this stub.
SELECT 1;
