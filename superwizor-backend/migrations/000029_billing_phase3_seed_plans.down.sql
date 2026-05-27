DELETE FROM subscription_plans WHERE display_name IN (
    'Solo Monthly', 'Solo Annual',
    'Pro Monthly', 'Pro Annual',
    'Clinic Monthly (5 licenses)', 'Clinic Annual (5 licenses)'
);
