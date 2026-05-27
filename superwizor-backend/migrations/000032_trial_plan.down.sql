-- Note: removing an enum value in Postgres requires recreating the type.
-- We leave the value behind on rollback — any existing TRIAL subscription
-- rows would otherwise become invalid. Drop the seeded plan row only.

DELETE FROM subscription_plans WHERE tier = 'TRIAL';
