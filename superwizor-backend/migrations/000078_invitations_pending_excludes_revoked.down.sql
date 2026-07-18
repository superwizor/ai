-- Rollback do predykatu z 000065 (bez revoked_at). Uwaga: przywraca
-- błąd revoke+reinvite — rollback tylko awaryjnie.
DROP INDEX IF EXISTS uq_invitations_patient_file_pending;

CREATE UNIQUE INDEX uq_invitations_patient_file_pending
    ON invitations(patient_file_id)
    WHERE accepted_at IS NULL AND invited_role = 'PATIENT';
