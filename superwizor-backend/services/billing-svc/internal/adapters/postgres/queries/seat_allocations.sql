-- Seat allocations — billing-svc side (docs/38 §3-4).
--
-- billing-svc OWNS org_seat_allocations writes (AdminSetSeatAllocations);
-- identity-svc reads them for invite-time seat checks. seat_assignments
-- is written by identity-svc (AcceptInvitation / SetTherapistStatus);
-- billing reads it for occupancy + counter provisioning.

-- name: UpsertSeatAllocation :one
INSERT INTO org_seat_allocations (
    organization_id, plan_id, seats, price_gross_per_seat, currency_code
) VALUES ($1, $2, $3, $4, $5)
ON CONFLICT (organization_id, plan_id) DO UPDATE
SET seats = EXCLUDED.seats,
    price_gross_per_seat = EXCLUDED.price_gross_per_seat,
    currency_code = EXCLUDED.currency_code,
    updated_at = now()
RETURNING id, organization_id, plan_id, seats, price_gross_per_seat,
          currency_code, created_at, updated_at;

-- name: ListSeatAllocationsByOrg :many
-- Allocation + catalog plan join + both occupancy halves (docs/38 §3:
-- active assignments + pending unexpired invitations).
SELECT a.id, a.organization_id, a.plan_id, a.seats,
       a.price_gross_per_seat, a.currency_code,
       p.tier AS plan_tier, p.cycle AS plan_cycle,
       p.price_gross AS catalog_price_gross,
       p.tokens_per_period,
       (SELECT COUNT(*) FROM seat_assignments sa
         WHERE sa.allocation_id = a.id AND sa.unassigned_at IS NULL) AS seats_assigned,
       (SELECT COUNT(*) FROM invitations i
         WHERE i.allocation_id = a.id AND i.accepted_at IS NULL
           AND i.expires_at > now()) AS seats_pending
FROM org_seat_allocations a
JOIN subscription_plans p ON p.id = a.plan_id
WHERE a.organization_id = $1
ORDER BY p.tier, p.cycle;

-- name: OrgHasSeatAllocations :one
-- Renewal-policy switch (docs/38): admin-provisioned B2B orgs (invoiced
-- offline) auto-renew their MANUAL subscription; other MANUAL subs are
-- canceled at period end (2026-07 incident policy).
SELECT EXISTS(
    SELECT 1 FROM org_seat_allocations WHERE organization_id = $1
) AS has_allocations;

-- name: ListSeatedTherapistsByOrg :many
-- Active (seated) therapists + their seat's plan — counter provisioning
-- in AdminSetSeatAllocations and the GetMyOrgSeatUsage dashboard.
SELECT u.id AS therapist_id, u.first_name, u.last_name, u.is_active,
       a.id AS allocation_id, a.plan_id,
       p.tier AS plan_tier, p.tokens_per_period
FROM seat_assignments sa
JOIN users u ON u.id = sa.user_id
JOIN org_seat_allocations a ON a.id = sa.allocation_id
JOIN subscription_plans p ON p.id = a.plan_id
WHERE a.organization_id = $1
  AND sa.unassigned_at IS NULL
  AND u.deleted_at IS NULL
ORDER BY u.last_name, u.first_name;

-- name: GetSeatPlanForTherapist :one
-- Lazy counter creation on the debit path: which plan does the caller's
-- open seat sit in? ErrNoRows = therapist has no seat (org-level
-- fallback applies).
SELECT a.organization_id, p.id AS plan_id, p.tokens_per_period
FROM seat_assignments sa
JOIN org_seat_allocations a ON a.id = sa.allocation_id
JOIN subscription_plans p ON p.id = a.plan_id
WHERE sa.user_id = $1 AND sa.unassigned_at IS NULL;

-- name: ListActiveTherapistCounters :many
-- Per-therapist usage for the current period (GetMyOrgSeatUsage).
SELECT c.therapist_id, c.tokens_used, c.tokens_reserved, c.tokens_limit,
       u.first_name, u.last_name, u.is_active
FROM usage_counters c
JOIN users u ON u.id = c.therapist_id
WHERE c.subscription_id = $1
  AND c.therapist_id IS NOT NULL
  AND c.period_start <= now()
  AND c.period_end > now()
ORDER BY u.last_name, u.first_name;
-- name: GetPlanByID :one
SELECT id, tier, cycle, display_name, price_gross, currency_code,
       tokens_per_period, licenses_limit, is_active
FROM subscription_plans
WHERE id = $1;

-- name: CreateManualSubscription :one
-- Admin-provisioned B2B subscription (docs/38 §4). provider_subscription_id
-- is deterministic ("b2b-<org>") so a wizard retry collides on the
-- UNIQUE(provider, provider_subscription_id) instead of double-creating.
INSERT INTO subscriptions (
    organization_id, plan_id, provider, provider_subscription_id,
    status, current_period_start, current_period_end
) VALUES (
    $1, $2, 'MANUAL', $3, 'ACTIVE', $4, $5
)
RETURNING id, organization_id, plan_id, current_period_start, current_period_end;
