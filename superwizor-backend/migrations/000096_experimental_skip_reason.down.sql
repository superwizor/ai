DROP INDEX IF EXISTS idx_experimental_skip_by_session;
ALTER TABLE experimental_report_requests
    DROP COLUMN IF EXISTS skip_reason,
    DROP COLUMN IF EXISTS skip_detail;
