ALTER TABLE report_run_context DROP COLUMN IF EXISTS similarity;
ALTER TABLE report_run_context_stats
    DROP COLUMN IF EXISTS semantic_enabled,
    DROP COLUMN IF EXISTS semantic_found,
    DROP COLUMN IF EXISTS semantic_below_threshold;
