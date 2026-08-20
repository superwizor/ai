-- Reverses 000087.
--
-- Dropping template_id/template_version from reports loses the
-- provenance of every template-generated document — they become
-- indistinguishable from standard pipeline output. Export before running
-- this on an environment where templates have been used.
ALTER TABLE reports
    DROP COLUMN IF EXISTS template_version,
    DROP COLUMN IF EXISTS template_id;

DROP TABLE IF EXISTS report_templates;
