-- name: CreatePatientFile :one
-- patient_id is the FK to the paired users row (role='PATIENT'),
-- created by clinical-svc.CreatePatientFile handler immediately
-- before this insert. The handler runs both in one transaction so
-- patient_file never points at a missing user.
--
-- consent_given_at is set to now() at insert time iff has_recording_consent
-- is true. This stamps when the therapist confirmed consent in our system —
-- the boolean alone gives no audit trail, and RODO inspections / supervisor
-- audits routinely ask "when was consent given?". If consent is later
-- revoked (separate flow, not implemented yet), the timestamp stays as
-- the historical record of when it was originally granted.
INSERT INTO patient_files (
  therapist_id, patient_id, modality_id, working_alias,
  process_type, initial_complaint, has_recording_consent,
  consent_given_at
) VALUES (
  $1, $2, $3, $4, $5, $6, $7,
  CASE WHEN $7::boolean THEN now() ELSE NULL END
)
RETURNING *;

-- name: GetPatientFile :one
-- Kept for code paths that don't need user fields (e.g. internal
-- authz/ownership checks). External callers use GetPatientFileWithUser.
SELECT * FROM patient_files
WHERE id = $1 AND deleted_at IS NULL;

-- name: GetPatientFileWithUser :one
-- Returns the patient_file plus the JOINed user fields used in the
-- proto response. LEFT JOIN on users because patient_id may be NULL
-- after DeletePatientUser left an orphan (only possible before
-- migration 000014's CASCADE flip; kept LEFT for defensiveness on
-- already-orphaned rows in production). NULL user columns are
-- emitted as empty strings by the proto mapper.
--
-- INNER JOIN on modalities — patient_files.modality_id is NOT NULL
-- (migration 000005), so an INNER JOIN won't drop any rows but does
-- give us a non-null `modality_code` to populate the proto response
-- without a second round-trip. Closes the "modality empty after
-- create" gap surfaced by the previous Faza 2 TODO.
SELECT
  pf.*,
  u.first_name  AS patient_first_name,
  u.last_name   AS patient_last_name,
  u.ui_language AS patient_language_code,
  m.system_code AS modality_code
FROM patient_files pf
LEFT JOIN users u ON u.id = pf.patient_id AND u.role = 'PATIENT' AND u.deleted_at IS NULL
INNER JOIN modalities m ON m.id = pf.modality_id
WHERE pf.id = $1 AND pf.deleted_at IS NULL;

-- name: ListPatientFilesByTherapist :many
SELECT * FROM patient_files
WHERE therapist_id = $1 AND deleted_at IS NULL
ORDER BY created_at DESC
LIMIT $2 OFFSET $3;

-- name: ListPatientFilesByTherapistWithUser :many
-- See GetPatientFileWithUser comment for the JOIN strategy. Same
-- shape, just the WHERE switches to therapist_id + paged.
SELECT
  pf.*,
  u.first_name  AS patient_first_name,
  u.last_name   AS patient_last_name,
  u.ui_language AS patient_language_code,
  m.system_code AS modality_code
FROM patient_files pf
LEFT JOIN users u ON u.id = pf.patient_id AND u.role = 'PATIENT' AND u.deleted_at IS NULL
INNER JOIN modalities m ON m.id = pf.modality_id
WHERE pf.therapist_id = $1 AND pf.deleted_at IS NULL
ORDER BY pf.created_at DESC
LIMIT $2 OFFSET $3;

-- name: CountPatientFilesByTherapist :one
SELECT COUNT(*) FROM patient_files
WHERE therapist_id = $1 AND deleted_at IS NULL;

-- name: UpdatePatientFile :one
-- Mutates only the therapist-editable kartoteka fields. modality_id is
-- intentionally NOT here: sessions/reports were analyzed under the
-- modality picked at create time, and silently swapping it would
-- re-frame past clinical work. See PatientFile.modality_id in
-- clinical.proto. process_type follows the same logic.
-- Patient-user fields (first_name/last_name/language_code) live in
-- patient_users.sql::UpdatePatientUser.
UPDATE patient_files SET
  working_alias = COALESCE(NULLIF($2, ''), working_alias),
  initial_complaint = NULLIF($3, ''),
  private_therapist_notes = NULLIF($4, ''),
  is_process_closed = $5,
  updated_at = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING *;

-- name: SoftDeletePatientFile :exec
-- Kept for backwards compatibility — old gRPC handlers may still call
-- it. New code (post-000012) uses HardDeletePatientFile to satisfy
-- RODO right-to-erasure.
UPDATE patient_files SET deleted_at = now()
WHERE id = $1 AND therapist_id = $2;

-- name: HardDeletePatientFile :execrows
-- Permanent removal. Migration 000012 added ON DELETE CASCADE on
-- sessions.patient_file_id and audio_uploads.patient_file_id, so all
-- child sessions (and their transcripts/reports/hitop rows via the
-- second-level cascade) get wiped in a single statement.
-- therapist_id predicate is the authz guard at the SQL layer.
-- Returns row count so caller can distinguish 404 from success.
DELETE FROM patient_files WHERE id = $1 AND therapist_id = $2;

-- name: ListSessionIDsForPatientFile :many
-- Pre-fetched BEFORE HardDeletePatientFile runs, so the caller can
-- publish one session.deleted Pub/Sub event per affected session for
-- Firestore + inbox cleanup downstream. After the hard delete the
-- rows are gone and we'd have nothing to publish.
SELECT id FROM sessions WHERE patient_file_id = $1 AND deleted_at IS NULL;
