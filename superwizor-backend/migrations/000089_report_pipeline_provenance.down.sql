DROP INDEX IF EXISTS idx_reports_pipeline;
ALTER TABLE reports
    DROP COLUMN IF EXISTS validator_version,
    DROP COLUMN IF EXISTS prompt_versions,
    DROP COLUMN IF EXISTS ontology_version,
    DROP COLUMN IF EXISTS pipeline_version;
