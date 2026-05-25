-- Manual seed dla E2E billing tests (staging).
-- Idempotent — re-run nic nie psuje. UUIDy hardcoded żeby:
--   1) E2E test używał stałych ID (no resolve)
--   2) cleanup był deterministic
--
-- Reference: docs/16_BILLING_SERVICE_PHASE_3.md, tests/e2e/billing_test.go
--
-- Cleanup po zakończonych testach:
--   DELETE FROM usage_events WHERE organization_id = '99000000-0000-0000-0000-000000000001';
--   DELETE FROM pending_reservations WHERE organization_id = '99000000-0000-0000-0000-000000000001';
--   DELETE FROM outbox_events WHERE organization_id = '99000000-0000-0000-0000-000000000001';
--   DELETE FROM usage_counters WHERE subscription_id IN (SELECT id FROM subscriptions WHERE organization_id = '99000000-0000-0000-0000-000000000001');
--   DELETE FROM subscriptions WHERE organization_id = '99000000-0000-0000-0000-000000000001';
--   DELETE FROM users WHERE organization_id = '99000000-0000-0000-0000-000000000001';
--   DELETE FROM organizations WHERE id = '99000000-0000-0000-0000-000000000001';
--   DELETE FROM addresses WHERE id = '99000000-0000-0000-0000-00000000aaaa';

BEGIN;

-- 1. Address (minimal, required by organizations.headquarters_address_id FK).
INSERT INTO addresses (
    id, country_code, region, city, postal_code,
    street_line, building_number
) VALUES (
    '99000000-0000-0000-0000-00000000aaaa',
    'PL', 'mazowieckie', 'Warszawa', '00-001',
    'Test Street', '1'
)
ON CONFLICT (id) DO NOTHING;

-- 2. Organization (SOLO type). primary_admin_user_id zostaje NULL na razie —
-- ustawimy w kroku 3 po utworzeniu therapista.
INSERT INTO organizations (
    id, legal_name, headquarters_address_id, type
) VALUES (
    '99000000-0000-0000-0000-000000000001',
    'E2E Billing Test Org',
    '99000000-0000-0000-0000-00000000aaaa',
    'SOLO'
)
ON CONFLICT (id) DO NOTHING;

-- 3. Therapist user. firebase_uid musi być unique — używamy stałego stringa
-- z prefixem "e2e-billing-" żeby nie kolidować z realnymi userami.
INSERT INTO users (
    id, role, organization_id,
    firebase_uid, email,
    first_name, last_name,
    ui_language, timezone,
    has_accepted_tos
) VALUES (
    '99000000-0000-0000-0000-000000000002',
    'THERAPIST', '99000000-0000-0000-0000-000000000001',
    'e2e-billing-therapist-uid',
    'e2e-billing-therapist@example.test',
    'E2E', 'Therapist',
    'pl', 'Europe/Warsaw',
    true
)
ON CONFLICT (id) DO NOTHING;

-- Patch organizations.primary_admin_user_id (nieidempotentne kiedy DO NOTHING
-- zostawia NULL — robimy explicit UPDATE).
UPDATE organizations
SET primary_admin_user_id = '99000000-0000-0000-0000-000000000002'
WHERE id = '99000000-0000-0000-0000-000000000001'
  AND primary_admin_user_id IS NULL;

-- 4. MANUAL ACTIVE subscription dla tej org. Plan: PRO MONTHLY (40 tokenów).
INSERT INTO subscriptions (
    id, organization_id, plan_id,
    provider, provider_subscription_id,
    status,
    current_period_start, current_period_end
)
SELECT
    '99000000-0000-0000-0000-000000000003',
    '99000000-0000-0000-0000-000000000001',
    p.id,
    'MANUAL',
    'manual-e2e-billing-test',
    'ACTIVE',
    date_trunc('month', now()),
    date_trunc('month', now()) + interval '1 month'
FROM subscription_plans p
WHERE p.tier = 'PRO' AND p.cycle = 'MONTHLY' AND p.is_active = TRUE
LIMIT 1
ON CONFLICT (id) DO NOTHING;

-- 5. usage_counters dla bieżącego okresu.
INSERT INTO usage_counters (
    id, subscription_id, period_start, period_end,
    tokens_used, tokens_reserved, tokens_limit
) VALUES (
    '99000000-0000-0000-0000-000000000004',
    '99000000-0000-0000-0000-000000000003',
    date_trunc('month', now()),
    date_trunc('month', now()) + interval '1 month',
    0, 0, 40
)
ON CONFLICT (id) DO NOTHING;

COMMIT;

-- Verification queries
SELECT 'org' AS what, id::text FROM organizations WHERE id = '99000000-0000-0000-0000-000000000001'
UNION ALL SELECT 'user', id::text FROM users WHERE id = '99000000-0000-0000-0000-000000000002'
UNION ALL SELECT 'subscription', id::text FROM subscriptions WHERE id = '99000000-0000-0000-0000-000000000003'
UNION ALL SELECT 'counter', id::text FROM usage_counters WHERE id = '99000000-0000-0000-0000-000000000004';
