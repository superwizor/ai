-- name: CreateInvoice :one
INSERT INTO invoices (
    organization_id, subscription_id, stripe_invoice_id,
    amount_paid, currency, invoice_pdf, hosted_invoice_url,
    period_start, period_end, created_at
) VALUES (
    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10
)
ON CONFLICT (stripe_invoice_id) DO UPDATE
    SET amount_paid = EXCLUDED.amount_paid,
        invoice_pdf = EXCLUDED.invoice_pdf,
        hosted_invoice_url = EXCLUDED.hosted_invoice_url,
        period_start = EXCLUDED.period_start,
        period_end = EXCLUDED.period_end
RETURNING id, organization_id, subscription_id, stripe_invoice_id, amount_paid, currency, invoice_pdf, hosted_invoice_url, period_start, period_end, created_at;

-- name: ListInvoicesByOrg :many
SELECT id, organization_id, subscription_id, stripe_invoice_id,
       amount_paid, currency, invoice_pdf, hosted_invoice_url,
       period_start, period_end, created_at
FROM invoices
WHERE organization_id = $1
ORDER BY created_at DESC;
