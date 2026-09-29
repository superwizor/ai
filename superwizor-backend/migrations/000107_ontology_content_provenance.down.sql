DROP TRIGGER IF EXISTS trg_ontology_versions_audit_content ON ontology_versions;
DROP FUNCTION IF EXISTS ontology_versions_audit_content();
ALTER TABLE reports DROP COLUMN IF EXISTS ontology_content_sha256;
