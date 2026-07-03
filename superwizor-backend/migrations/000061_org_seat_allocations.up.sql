-- 000061: Seat allocations per organization × plan (docs/38 §3).
--
-- SUPERWIZOR_ADMIN provisions an organization with N seats in a given
-- plan at a (possibly negotiated) per-seat price. `licenses_limit` on
-- subscription_plans is a catalog default; THIS table is the actual
-- per-organization allocation the seat-limit checks run against.
--
-- price_gross_per_seat NULL = use the catalog plan.price_gross.
-- Invoice value = Σ(seats × COALESCE(price_gross_per_seat, plan.price_gross)).

CREATE TABLE org_seat_allocations (
    id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id      UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plan_id              UUID NOT NULL REFERENCES subscription_plans(id) ON DELETE RESTRICT,
    seats                INT  NOT NULL,
    price_gross_per_seat NUMERIC(10,2),
    currency_code        CHAR(3) NOT NULL DEFAULT 'PLN',

    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT uq_seat_alloc_org_plan UNIQUE (organization_id, plan_id),
    CONSTRAINT chk_seat_alloc_seats   CHECK (seats >= 0),
    CONSTRAINT chk_seat_alloc_price   CHECK (price_gross_per_seat IS NULL OR price_gross_per_seat >= 0)
);

-- /org panel + seat-limit validation always scan by organization.
CREATE INDEX idx_seat_alloc_org ON org_seat_allocations(organization_id);

COMMENT ON TABLE org_seat_allocations IS
    'Per-organization seat purchase: how many therapist seats in which plan, '
    'at what negotiated price. Occupancy = active seat_assignments + pending '
    'invitations for the allocation (docs/38 §3).';
