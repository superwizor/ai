-- Migration: Fix platform fixed costs amount_usd values to be USD equivalent of real PLN invoices (using 4.05 exchange rate)
UPDATE platform_fixed_costs SET amount_usd = 27.1605 WHERE name = 'Cloud SQL db-f1-micro instance';
UPDATE platform_fixed_costs SET amount_usd = 2.4691 WHERE name = 'Cloud SQL 10GB Storage';
UPDATE platform_fixed_costs SET amount_usd = 12.3457 WHERE name = 'Cloud Run baseline (CPU/Memory allocation)';
UPDATE platform_fixed_costs SET amount_usd = 1.9753 WHERE name = 'KMS Keyring & Keys baseline active usage';
UPDATE platform_fixed_costs SET amount_usd = 0.4938 WHERE name = 'Artifact Registry baseline storage';
