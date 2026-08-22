DROP TRIGGER IF EXISTS trg_ontology_versions_guard_approved ON ontology_versions;
DROP FUNCTION IF EXISTS ontology_versions_guard_approved();
ALTER TABLE modalities DROP COLUMN IF EXISTS active_ontology_version_id;
DROP TABLE IF EXISTS ontology_versions;
DROP TYPE IF EXISTS ontology_status;
