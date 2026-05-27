-- Phase 3 billing: nowy enum dla cyklu życia rezerwacji tokenów (ADR-BL-001).
-- Pozostałe billing enumy (plan_tier, billing_cycle, payment_provider,
-- subscription_status) już istnieją od migracji 000002.
--
-- Reference: docs/16_BILLING_SERVICE_PHASE_3.md §3.1.

CREATE TYPE reservation_status AS ENUM (
    'ACTIVE',          -- reserved, czeka na commit
    'COMMITTED',       -- token spalony, finalized
    'RELEASED',        -- explicit release (np. upload failed)
    'EXPIRED'          -- TTL przekroczone, cron release
);
