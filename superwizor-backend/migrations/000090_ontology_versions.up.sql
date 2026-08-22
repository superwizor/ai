-- Ontology Studio: wersje ontologii w bazie (plan 16 v1.2, sekcja 4.1).
--
-- Zmiana wzgledem dok. 11 D2: tresc ontologii przestaje byc plikiem w
-- repo pod CODEOWNERS, a staje sie wersjonowanym rekordem edytowanym w
-- aplikacji. Cztery wlasnosci starego mechanizmu sa odtworzone tutaj i
-- w RPC, i sa nienegocjowalne (adnotacja do D2 w dok. 11):
--
--   (a) wersja `approved` jest NIEMUTOWALNA — pilnuje tego trigger nizej;
--   (b) autor nie zatwierdza wlasnej wersji (four-eyes) — CHECK + RPC;
--   (c) walidacja metaschematem jest twarda — pkg/ontology, serwerowo;
--   (d) audyt kazdego przejscia z nota — kolumny *_note + admin_audit.
--
-- Wzorzec tabeli swiadomie lustrzany wobec modality_prompt_versions:
-- append-only historia + wskaznik wersji zywej na modalnosci. Zespol zna
-- ten ksztalt z Prompt Studio, wiec Studio ontologii nie wprowadza
-- nowego modelu mentalnego.

CREATE TYPE ontology_status AS ENUM ('draft', 'ready_for_review', 'approved');

CREATE TABLE ontology_versions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    modality_id     UUID NOT NULL REFERENCES modalities(id) ON DELETE RESTRICT,

    -- semver tresci; unikalny w obrebie modalnosci
    version         TEXT NOT NULL,
    -- Pelna tresc ontologii. JSONB, nie TEXT: panel Jakosci i benchmark
    -- pytaja o pojedyncze konstrukty bez parsowania calosci w Go.
    content         JSONB NOT NULL,

    status          ontology_status NOT NULL DEFAULT 'draft',

    created_by      UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_note     TEXT NOT NULL,

    submitted_at    TIMESTAMPTZ,
    -- approved_by jest ROZNE od created_by — to jest four-eyes zapisane
    -- w schemacie, nie tylko w kodzie RPC.
    approved_by     UUID REFERENCES users(id) ON DELETE RESTRICT,
    approved_at     TIMESTAMPTZ,
    approval_note   TEXT,

    UNIQUE (modality_id, version),

    CONSTRAINT ontology_four_eyes
        CHECK (approved_by IS NULL OR approved_by <> created_by),
    CONSTRAINT ontology_approved_complete
        CHECK (status <> 'approved'
               OR (approved_by IS NOT NULL AND approved_at IS NOT NULL))
);

CREATE INDEX idx_ontology_versions_modality
    ON ontology_versions(modality_id, created_at DESC);
CREATE INDEX idx_ontology_versions_status
    ON ontology_versions(status) WHERE status <> 'approved';

-- Wskaznik wersji AKTYWNEJ na produkcji.
--
-- Osobny od statusu, bo to dwie rozne decyzje i dwie rozne role:
-- `approved` mowi "tresc jest merytorycznie w porzadku" (ONTOLOGY_EDITOR),
-- `active_ontology_version_id` mowi "tym generujemy raporty"
-- (SUPERWIZOR_ADMIN, dodatkowo po zielonym benchmarku). Status != live.
ALTER TABLE modalities
    ADD COLUMN IF NOT EXISTS active_ontology_version_id UUID
        REFERENCES ontology_versions(id) ON DELETE SET NULL;

COMMENT ON COLUMN modalities.active_ontology_version_id IS
    'Wersja serwowana na produkcji. Ustawia WYLACZNIE SUPERWIZOR_ADMIN na '
    'wersji approved z zielonym benchmarkiem. NULL = potok ontologiczny '
    'niedostepny dla tej modalnosci (fail-closed na legacy).';

-- Niemutowalnosc wersji zatwierdzonej.
--
-- W triggerze, nie w kodzie aplikacji: to jest wlasnosc, ktora zastapila
-- niemutowalnosc commita w gicie, wiec nie moze zalezec od tego, ktora
-- sciezka kodu dokonuje zapisu. Dozwolone jest wylacznie zejscie ze
-- statusu approved (wycofanie autoryzacji) — i nic poza tym.
CREATE OR REPLACE FUNCTION ontology_versions_guard_approved()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'approved' THEN
        IF NEW.content IS DISTINCT FROM OLD.content
           OR NEW.version IS DISTINCT FROM OLD.version
           OR NEW.modality_id IS DISTINCT FROM OLD.modality_id THEN
            RAISE EXCEPTION
                'wersja zatwierdzona jest niemutowalna — utworz nowy draft (%.%)',
                OLD.modality_id, OLD.version;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_ontology_versions_guard_approved
    BEFORE UPDATE ON ontology_versions
    FOR EACH ROW EXECUTE FUNCTION ontology_versions_guard_approved();
