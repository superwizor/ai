-- Proweniencja TRESCI ontologii na raporcie + audyt zmian tresci wersji.
--
-- Raport zapisywal wylacznie etykiete wersji (reports.ontology_version,
-- np. '0.1.1'), a wersje robocza (draft) mozna nadpisywac w miejscu —
-- razem z notatka zmiany. Kanarek PPT 2026-09-28: raport odrzucil
-- twierdzenie z progiem "wymagane 2", a szkic 0.1.1 ma dzis w bazie
-- prog 1. Tresci, na ktorej powstal raport, nie da sie odtworzyc ani
-- nawet ustalic, kiedy sie zmienila.

-- SHA-256 (hex) tresci YAML, ktora FAKTYCZNIE weszla do przebiegu —
-- liczony z tych samych bajtow, ktore sparsowal potok. NULL dla raportow
-- legacy i sprzed tej migracji (nieznane, a nie "puste").
ALTER TABLE reports ADD COLUMN ontology_content_sha256 TEXT;

COMMENT ON COLUMN reports.ontology_content_sha256 IS
    'SHA-256 (hex) tresci ontology_versions.content uzytej przez potok; '
    'porownywalny z audit_events.metadata->>''sha256_after'' (action ontology.content_changed).';

-- Kazda zmiana tresci wersji zostawia slad: skrot przed i po oraz obie
-- notatki zmiany (UPDATE szkicu nadpisuje change_note). Trigger, a nie
-- kod Ontology Studio, bo ma lapac takze zmiany spoza Studio.
CREATE OR REPLACE FUNCTION ontology_versions_audit_content()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO audit_events (action, resource_type, resource_id, metadata)
    VALUES ('ontology.content_changed', 'ontology_version', NEW.id,
            jsonb_build_object(
                'version', NEW.version,
                'status', OLD.status,
                'sha256_before', encode(sha256(convert_to(OLD.content, 'UTF8')), 'hex'),
                'sha256_after', encode(sha256(convert_to(NEW.content, 'UTF8')), 'hex'),
                'change_note_before', OLD.change_note,
                'change_note_after', NEW.change_note));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ontology_versions_audit_content
    AFTER UPDATE OF content ON ontology_versions
    FOR EACH ROW
    WHEN (OLD.content IS DISTINCT FROM NEW.content)
    EXECUTE FUNCTION ontology_versions_audit_content();
