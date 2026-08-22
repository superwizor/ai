ALTER TABLE ontology_versions DROP COLUMN IF EXISTS construct_count;
ALTER TABLE ontology_versions
    ALTER COLUMN content TYPE JSONB USING to_jsonb(content);
