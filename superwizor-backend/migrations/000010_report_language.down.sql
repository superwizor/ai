BEGIN;

ALTER TABLE sessions DROP COLUMN IF EXISTS report_language;

UPDATE modalities
SET therapist_ai_general_prompt = REPLACE(
    therapist_ai_general_prompt::text,
    'we wskazanym języku.',
    'w języku polskim.'
)::jsonb;

UPDATE modalities
SET patient_ai_general_prompt = REPLACE(
    patient_ai_general_prompt::text,
    'we wskazanym języku.',
    'w języku polskim.'
)::jsonb;

COMMIT;
