CREATE TABLE invoices (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id     UUID NOT NULL REFERENCES organizations(id) ON DELETE RESTRICT,
    subscription_id     UUID REFERENCES subscriptions(id) ON DELETE SET NULL,
    
    stripe_invoice_id   VARCHAR(255) NOT NULL UNIQUE,
    amount_paid         NUMERIC(10,2) NOT NULL,
    currency            CHAR(3) NOT NULL,
    
    invoice_pdf         TEXT NOT NULL,
    hosted_invoice_url  TEXT NOT NULL,
    
    period_start        TIMESTAMPTZ NOT NULL,
    period_end          TIMESTAMPTZ NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_invoices_organization ON invoices(organization_id, created_at DESC);
