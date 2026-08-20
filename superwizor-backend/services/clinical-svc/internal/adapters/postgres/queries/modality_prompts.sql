-- Admin Prompt Studio (docs/31) — versioned modality prompt queries.
-- The live prompt stays in modalities.therapist_ai_general_prompt
-- (llm-worker reads it per report); modality_prompt_versions is the
-- append-only history. AdminUpdateModalityPrompt wraps UpdateModality-
-- LivePrompt + InsertModalityPromptVersion in one transaction with an
-- optimistic-lock check against GetLatestModalityPromptVersion.

-- name: AdminListModalityPrompts :many
-- Every modality (supported or not) with its live prompt text and the
-- latest version metadata. LEFT JOINs tolerate a modality that predates
-- the 000052 backfill (version 0, empty author).
SELECT m.id, m.system_code, m.display_name, m.modality_type::text AS modality_type,
       m.is_supported,
       COALESCE(m.therapist_ai_general_prompt->>'system', '')::text AS system_prompt,
       COALESCE(m.therapist_ai_general_prompt->>'chat', '')::text AS chat_prompt,
       COALESCE(v.version, 0)::int AS version,
       COALESCE(u.email, '')::text AS updated_by_email,
       -- epoch sentinel when the modality predates the 000052 backfill
       -- (version=0); the handler omits the timestamp for version 0.
       COALESCE(v.created_at, 'epoch'::timestamptz) AS updated_at
FROM modalities m
LEFT JOIN LATERAL (
    SELECT version, created_by, created_at
    FROM modality_prompt_versions
    WHERE modality_id = m.id
    ORDER BY version DESC
    LIMIT 1
) v ON TRUE
LEFT JOIN users u ON u.id = v.created_by
ORDER BY m.display_name;

-- name: GetLatestModalityPromptVersion :one
-- Optimistic-lock read. FOR UPDATE on the modality row serializes two
-- concurrent admin saves on the same modality (the version check then
-- decides the loser deterministically).
SELECT COALESCE((
    SELECT MAX(version) FROM modality_prompt_versions WHERE modality_id = m.id
), 0)::int AS latest_version
FROM modalities m
WHERE m.id = $1
FOR UPDATE OF m;

-- name: UpdateModalityLivePrompt :exec
-- jsonb_set, NIGDY jsonb_build_object: kolumna niesie od 20.08.2026 takze
-- klucz 'chat' (soczewka modalnosci w czacie, seed z
-- migrations/modality_prompts/chat_*.txt). Przebudowa obiektu od zera
-- kasowalaby po cichu kazdy klucz poza 'system' przy najblizszej edycji
-- promptu raportowego w Prompt Studio. Pilnuje tego test zrodlowy
-- TestPromptStudioWritesDoNotDropSiblingKeys.
UPDATE modalities
SET therapist_ai_general_prompt =
    jsonb_set(coalesce(therapist_ai_general_prompt, '{}'::jsonb),
              '{system}', to_jsonb(sqlc.arg(system_prompt)::text), true)
WHERE id = $1;

-- name: UpdateModalityLiveChatPrompt :exec
-- Blizniak UpdateModalityLivePrompt dla klucza 'chat' (soczewka czatu).
-- Ta sama zasada: jsonb_set na JEDNYM kluczu, nigdy odbudowa obiektu.
-- Pusty tekst jest poprawny i wylacza soczewke tej modalnosci — czat
-- wraca wtedy do golych promptow per intencja.
UPDATE modalities
SET therapist_ai_general_prompt =
    jsonb_set(coalesce(therapist_ai_general_prompt, '{}'::jsonb),
              '{chat}', to_jsonb(sqlc.arg(chat_prompt)::text), true)
WHERE id = $1;

-- name: InsertModalityPromptVersion :one
-- Snapshot CALEJ zywej kolumny (po UPDATE w tej samej transakcji), nie
-- odbudowa {'system': ...}: historia ma oddawac stan faktyczny, wlacznie
-- z kluczem 'chat'. Snapshot budowany z parametru gubilby klucze
-- rownolegle i przywrocenie wersji tez by je kasowalo.
INSERT INTO modality_prompt_versions (modality_id, version, prompt, change_note, created_by)
SELECT $1, $2, m.therapist_ai_general_prompt, $3, $4
  FROM modalities m WHERE m.id = $1
RETURNING id, created_at;

-- name: ListModalityPromptVersions :many
-- History panel: newest first, offset-paged. limit+1 pattern for
-- has_more is applied by the handler.
SELECT v.id, v.version,
       COALESCE(v.prompt->>'system', '')::text AS system_prompt,
       COALESCE(v.prompt->>'chat', '')::text AS chat_prompt,
       v.change_note,
       COALESCE(u.email, '')::text AS created_by_email,
       v.created_at
FROM modality_prompt_versions v
LEFT JOIN users u ON u.id = v.created_by
WHERE v.modality_id = $1
ORDER BY v.version DESC
LIMIT $2 OFFSET $3;
