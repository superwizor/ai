-- 000087: report_templates — therapist-authored document templates.
--
-- Spec: docs/63 F10, decision D7 (2026-08-20).
--
-- ══ A template is a COMPOSITION, not a saved prompt ══
--
-- The obvious design — let a therapist save a prompt and replay it — was
-- rejected. A free prompt bypasses the layer that actually stops a
-- prohibited answer: the schema. ADR section 4.1 makes control
-- structural precisely because instructions are negotiable and schemas
-- are not, and a saved prompt would reintroduce a generative surface that
-- the classifier never sees. A shared one would propagate whatever it
-- encodes between therapists, which is a manufacturer's problem under the
-- MDR, not a user's.
--
-- So a template composes SECTIONS, each of a fixed type that maps onto an
-- executor the guardrail already governs. A section may carry a short
-- `instructions` string, which acts as a focus hint — freedom about WHAT
-- to look at, none about which rules apply. The prohibited categories are
-- unreachable by construction: there is no section type that produces
-- one.
--
-- ══ Versions are append-only ══
--
-- Editing a template creates a new version; the old rows stay. A
-- generated document records (template_id, template_version), so a
-- document produced six months ago can still be explained by the exact
-- template that produced it. Mutating in place would silently rewrite
-- the provenance of every document that came before.
--
-- ══ Sharing copies, it does not link ══
--
-- Using someone else's template forks a specific version into your own.
-- A live reference would let the author's later edit change the meaning
-- of documents other clinicians already filed under their own names.
--
-- ══ FK cascade rationale (ADR-DM-010) ══
--   - owner_therapist_id -> users.id ON DELETE CASCADE: a template
--     belongs to its author and carries no client data.
--   - organization_id -> organizations.id ON DELETE SET NULL: losing the
--     org makes the template private again rather than deleting work.

CREATE TABLE report_templates (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    owner_therapist_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- NULL = private. Non-NULL = visible to that organization, which is
    -- a deliberate act by the owner, never a default.
    organization_id     UUID REFERENCES organizations(id) ON DELETE SET NULL,

    name                TEXT NOT NULL,
    description         TEXT NOT NULL DEFAULT '',

    -- Monotonic per template. Together with id it identifies exactly
    -- what produced a given document.
    version             INT NOT NULL DEFAULT 1,

    -- The composition:
    --   [{ "type": "extract" | "quotes" | "summary" | "stats"
    --            | "user_only" | "generative_grounded",
    --      "title": "...",
    --      "instructions": "<=500 chars, only for generative_grounded" }]
    --
    -- Validated in application code at SAVE time (pkg/guardrail
    -- ValidateTemplateSections), not at run time: a template that could
    -- request a prohibited operation must be refused when it is written,
    -- while its author is present to be told why.
    sections            JSONB NOT NULL,

    -- Provenance when this template was forked from someone else's.
    forked_from_id      UUID REFERENCES report_templates(id) ON DELETE SET NULL,
    forked_from_version INT,

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    -- Soft delete: a template referenced by an already-generated
    -- document must remain resolvable.
    deleted_at          TIMESTAMPTZ,

    CONSTRAINT report_templates_version_positive CHECK (version >= 1),
    CONSTRAINT report_templates_sections_is_array CHECK (jsonb_typeof(sections) = 'array'),
    UNIQUE (id, version)
);

-- The therapist's own list.
CREATE INDEX idx_report_templates_owner
    ON report_templates(owner_therapist_id, updated_at DESC)
    WHERE deleted_at IS NULL;

-- The organization library.
CREATE INDEX idx_report_templates_org
    ON report_templates(organization_id, updated_at DESC)
    WHERE organization_id IS NOT NULL AND deleted_at IS NULL;

COMMENT ON TABLE report_templates IS
    'Therapist-authored document templates. A template composes typed '
    'SECTIONS over guardrailed executors — it is not a saved prompt '
    '(decision D7, docs/63 F10). Versions are append-only; sharing forks '
    'a version rather than linking to it.';

COMMENT ON COLUMN report_templates.sections IS
    'Array of typed sections. Validated at save time by pkg/guardrail. '
    'Prohibited operations are unreachable: no section type produces one.';

-- Which template produced a document, at which version. Without this a
-- generated document cannot be explained after the template moves on.
ALTER TABLE reports
    ADD COLUMN template_id      UUID REFERENCES report_templates(id) ON DELETE SET NULL,
    ADD COLUMN template_version INT;

COMMENT ON COLUMN reports.template_id IS
    'Template that produced this document, if any. NULL = the standard '
    'per-modality pipeline.';
