-- Reverses 000084. Dropping the table drops its indexes and seed rows.
--
-- Operational note: on a running system this removes the AI chat kill
-- switch. pkg/appconfig falls back to its compiled-in defaults, which are
-- deliberately the safe ones (chat disabled), so a down-migration fails
-- closed rather than open.
DROP TABLE IF EXISTS app_config;
