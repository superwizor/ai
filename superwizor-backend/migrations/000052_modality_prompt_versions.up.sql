-- 000052 — Admin Prompt Studio (docs/31): versioned history for
-- modalities.therapist_ai_general_prompt.
--
-- The LIVE prompt stays in modalities.therapist_ai_general_prompt —
-- llm-worker keeps reading it per report, untouched. This table is an
-- append-only sidecar: every AdminUpdateModalityPrompt save bumps the
-- live column AND inserts a full snapshot here in one transaction.
-- Invariant: live column == snapshot with the highest version per
-- modality. Restores re-apply an old snapshot as a NEW version, so
-- history is never rewritten.

CREATE TABLE modality_prompt_versions (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    modality_id   UUID NOT NULL REFERENCES modalities(id) ON DELETE CASCADE,
    version       INTEGER NOT NULL,
    -- Full {"system": …} snapshot, same shape as the live column.
    prompt        JSONB NOT NULL,
    -- The mandatory reason from the admin save dialog (≥10 chars,
    -- enforced at the RPC layer).
    change_note   TEXT NOT NULL,
    -- ON DELETE RESTRICT (default): prompt history is audit-grade —
    -- deleting an admin user must not orphan or cascade-drop lineage.
    created_by    UUID NOT NULL REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (modality_id, version)
);

-- History panel reads newest-first per modality.
CREATE INDEX idx_modality_prompt_versions_lookup
    ON modality_prompt_versions(modality_id, version DESC);

-- Backfill: snapshot every modality's current live prompt as version 1
-- so the history is never empty and the live==latest invariant holds
-- from day one. created_by = the oldest SUPERWIZOR_ADMIN (system
-- attribution for the seed state).
INSERT INTO modality_prompt_versions (modality_id, version, prompt, change_note, created_by)
SELECT m.id, 1, m.therapist_ai_general_prompt,
       'seed snapshot (migration 000052)',
       (SELECT u.id FROM users u WHERE u.role = 'SUPERWIZOR_ADMIN'
        ORDER BY u.created_at LIMIT 1)
FROM modalities m
WHERE EXISTS (SELECT 1 FROM users WHERE role = 'SUPERWIZOR_ADMIN');
