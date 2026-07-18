-- Client (patient) panel invitations — docs/39. Same-DB reads of
-- patient_files mirror the seats.sql precedent.

-- name: GetPatientFileForInvite :one
-- resolved_email: since migration 000077 the kartoteka stores no client
-- e-mail (docs/43 §4) — the activated account's users.email wins, else
-- the latest non-revoked invitation's address. NULL = nothing on file.
SELECT pf.id, pf.therapist_id, pf.patient_id,
  COALESCE(u.email, (
    SELECT i.email FROM invitations i
    WHERE i.patient_file_id = pf.id AND i.revoked_at IS NULL
    ORDER BY i.created_at DESC LIMIT 1
  )) AS resolved_email
FROM patient_files pf
LEFT JOIN users u ON u.id = pf.patient_id AND u.role = 'PATIENT' AND u.deleted_at IS NULL
WHERE pf.id = $1 AND pf.deleted_at IS NULL;

-- name: GetPendingPatientInvitationByFile :one
SELECT * FROM invitations
WHERE patient_file_id = $1 AND invited_role = 'PATIENT' AND accepted_at IS NULL AND revoked_at IS NULL;

-- name: SetPatientFilePatientID :exec
UPDATE patient_files SET patient_id = $2 WHERE id = $1;

-- name: ActivatePatientUser :one
-- Attach-not-create (docs/39 D1): the accept flow fills in the auth
-- identity on the EXISTING patient row. No name stamping (docs/43 §4:
-- the client's only direct identifier is the e-mail; the kartoteka
-- identifies the client by working_alias).
UPDATE users
SET firebase_uid     = $2,
    email            = $3,
    has_accepted_tos = TRUE
WHERE id = $1 AND role = 'PATIENT' AND deleted_at IS NULL
RETURNING *;
