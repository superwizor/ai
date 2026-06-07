-- name: GetPlatformFixedCosts :many
-- CROSS-SERVICE READ: analytics-only
SELECT id, name, provider, amount_usd::float AS amount_usd, billing_period, created_at
FROM platform_fixed_costs
ORDER BY provider ASC, amount_usd DESC;
