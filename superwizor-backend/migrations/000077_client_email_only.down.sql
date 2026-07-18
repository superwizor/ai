-- Rollback 000077. patient_email wraca jako pusta kolumna (dane celowo
-- nieodtwarzalne - to byla usuwana duplikacja PII). Maskowanie
-- sent_to_email jest nieodwracalne z tego samego powodu.
ALTER TABLE patient_files ADD COLUMN IF NOT EXISTS patient_email TEXT;

COMMENT ON COLUMN patient_notes.sent_to_email IS NULL;
