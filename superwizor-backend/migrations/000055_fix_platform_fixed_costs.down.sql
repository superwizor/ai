-- Migration: Revert fix of platform fixed costs amount_usd values to original seed values
UPDATE platform_fixed_costs SET amount_usd = 9.3000 WHERE name = 'Cloud SQL db-f1-micro instance';
UPDATE platform_fixed_costs SET amount_usd = 1.7000 WHERE name = 'Cloud SQL 10GB Storage';
UPDATE platform_fixed_costs SET amount_usd = 2.5000 WHERE name = 'Cloud Run baseline (CPU/Memory allocation)';
UPDATE platform_fixed_costs SET amount_usd = 3.0000 WHERE name = 'KMS Keyring & Keys baseline active usage';
UPDATE platform_fixed_costs SET amount_usd = 0.5000 WHERE name = 'Artifact Registry baseline storage';
