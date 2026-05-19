-- Forward-only. Reverting would re-introduce the leak; if a real
-- need to rollback arises, restore from migration 000008's content
-- per-modality.
SELECT 'migration 000016 is forward-only (bug fix; nothing to revert)' AS note;
