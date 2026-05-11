BEGIN;

ALTER TABLE sessions ADD COLUMN report_language VARCHAR(10) DEFAULT 'pl' NOT NULL;

UPDATE modalities
SET therapist_ai_general_prompt = REPLACE(
    therapist_ai_general_prompt::text,
    'w języku polskim.',
    'we wskazanym języku.'
)::jsonb;

UPDATE modalities
SET patient_ai_general_prompt = REPLACE(
    patient_ai_general_prompt::text,
    'w języku polskim.',
    'we wskazanym języku.'
)::jsonb;

COMMIT;
