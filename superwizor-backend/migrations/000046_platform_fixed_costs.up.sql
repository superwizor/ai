-- Migration: Add platform_fixed_costs table and seed GCP/Firebase fixed costs

CREATE TABLE platform_fixed_costs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    provider VARCHAR(50) NOT NULL, -- 'GCP', 'Firebase'
    amount_usd NUMERIC(10, 4) NOT NULL,
    billing_period VARCHAR(50) NOT NULL DEFAULT 'monthly',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- Seed baseline staging/production fixed costs
INSERT INTO platform_fixed_costs (name, provider, amount_usd, billing_period) VALUES
('Cloud SQL db-f1-micro instance', 'GCP', 9.3000, 'monthly'),
('Cloud SQL 10GB Storage', 'GCP', 1.7000, 'monthly'),
('Cloud Run baseline (CPU/Memory allocation)', 'GCP', 2.5000, 'monthly'),
('Artifact Registry baseline storage', 'GCP', 0.5000, 'monthly'),
('KMS Keyring & Keys baseline active usage', 'GCP', 3.0000, 'monthly'),
('Firebase Authentication SMS baseline', 'Firebase', 0.0000, 'monthly'),
('Firebase Hosting custom domain SSL', 'Firebase', 0.0000, 'monthly'),
('Firebase Firestore baseline (free tier overlay)', 'Firebase', 0.0000, 'monthly');
