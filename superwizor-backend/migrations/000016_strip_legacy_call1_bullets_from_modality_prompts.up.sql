-- Strip three legacy "Wytyczne" bullets from every modality's
-- therapist_ai_general_prompt.system text. They predate the
-- call-1/call-2 split (ADR-IMPL-007):
--
--   - Speaker Role Inference: ...
--   - HiTOP Dimensions: ...
--   - RAG Summary Chunk: ...
--
-- Pre-split (migration 000008), the LLM ran in a single combined
-- call that produced metadata + report together, so it made sense to
-- list these as "report sections" the model should emit. Post-split,
-- those fields are produced by call 1 (metadata, JSON/Markdown-mode)
-- and stored as structured columns; call 2 is meant to produce only
-- the clinical-prose report_markdown.
--
-- Bug: the bullets were never pruned from the modality prompt. Call
-- 2's LLM faithfully follows the prompt and emits sections titled
-- "Speaker Role Inference", "HiTOP Dimensions", "RAG Summary Chunk"
-- at the top of report_markdown — duplicating the structured
-- speaker_role_inference column (with role labels echoed back as
-- text), polluting the rendered report with HiTOP rubric the
-- pipeline doesn't ingest anywhere, and *silently moving the
-- rag_summary_chunk content from its dedicated column into the
-- markdown body* (rag_summary_chunk ends up "" in the DB — see
-- production reports from 2026-05-18).
--
-- The fix is surgical: regexp_replace strips three consecutive
-- bullets, leading newline included, from every modality's prompt.
-- Idempotent — a re-run after the fix does nothing because the
-- pattern no longer matches. Affects 8 rows (UNIV, CBT, PSYCHO, PPT,
-- ST, SYS, EFT, COACH).
--
-- Reference report (decrypted prod sample, 2026-05-18):
--   id=693c8cda-6135-428c-804d-e244a1499f61
--   report_markdown starts with "**Speaker Role Inference:**" — exactly
--   what the LLM was asked for. Removing the bullets removes the ask.
--
-- Not touching patient_ai_general_prompt — audit showed those rows
-- don't have the bullets (system field empty / absent).

UPDATE modalities
SET therapist_ai_general_prompt = jsonb_set(
    therapist_ai_general_prompt,
    '{system}',
    to_jsonb(
        regexp_replace(
            therapist_ai_general_prompt->>'system',
            E'\n- Speaker Role Inference:[^\n]*\n- HiTOP Dimensions:[^\n]*\n- RAG Summary Chunk:[^\n]*',
            '',
            'g'
        )
    )
)
WHERE therapist_ai_general_prompt->>'system' LIKE '%Speaker Role Inference%'
  AND therapist_ai_general_prompt->>'system' LIKE '%HiTOP Dimensions%'
  AND therapist_ai_general_prompt->>'system' LIKE '%RAG Summary Chunk%';

-- Sanity check: post-update no row should contain any of the three.
-- If this RAISES, the regex didn't catch a variant — investigate
-- before deploying (don't ship a half-stripped prompt).
DO $$
DECLARE
    leftovers int;
BEGIN
    SELECT COUNT(*) INTO leftovers FROM modalities
     WHERE therapist_ai_general_prompt->>'system' LIKE '%Speaker Role Inference%'
        OR therapist_ai_general_prompt->>'system' LIKE '%HiTOP Dimensions%'
        OR therapist_ai_general_prompt->>'system' LIKE '%RAG Summary Chunk%';
    IF leftovers > 0 THEN
        RAISE EXCEPTION 'migration 000016: % modality prompt(s) still contain legacy bullets after regex', leftovers;
    END IF;
END $$;
