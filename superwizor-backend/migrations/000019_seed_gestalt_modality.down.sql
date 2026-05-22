-- Reversal: remove the GESTALT modality.
--
-- Safety note: this DELETE will fail if any patient_files reference
-- modality_id of this row (FK from migration 000005 + 000007). That is
-- intended — modality_code is immutable per ADR (see
-- docs/agents/06_flutter-therapist-app.md guardrails). If you need to
-- roll this back AND patient_files exist, first reassign their
-- modality_id manually before applying this down migration.

DELETE FROM modalities WHERE system_code = 'GESTALT';
