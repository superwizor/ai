-- Client (patient) panel invitations — docs/39. Same-DB reads of
-- patient_files mirror the seats.sql precedent.

-- name: GetPatientFileForInvite :one
SELECT id, therapist_id, patient_id, patient_email
FROM patient_files
WHERE id = $1 AND deleted_at IS NULL;

-- name: GetPendingPatientInvitationByFile :one
SELECT * FROM invitations
WHERE patient_file_id = $1 AND invited_role = 'PATIENT' AND accepted_at IS NULL;

-- name: SetPatientFileEmail :exec
UPDATE patient_files SET patient_email = $2 WHERE id = $1;

-- name: SetPatientFilePatientID :exec
UPDATE patient_files SET patient_id = $2 WHERE id = $1;

-- name: ActivatePatientUser :one
-- Attach-not-create (docs/39 D1): the accept flow fills in the auth
-- identity on the EXISTING patient row. Names update only when the
-- acceptor typed them.
UPDATE users
SET firebase_uid     = $2,
    email            = $3,
    first_name       = COALESCE(NULLIF($4::text, ''), first_name),
    last_name        = COALESCE(NULLIF($5::text, ''), last_name),
    has_accepted_tos = TRUE
WHERE id = $1 AND role = 'PATIENT' AND deleted_at IS NULL
RETURNING *;
