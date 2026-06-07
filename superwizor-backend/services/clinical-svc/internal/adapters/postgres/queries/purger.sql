-- name: GetExpiredPatientUsers :many
SELECT id FROM users
WHERE role = 'PATIENT' AND deleted_at < NOW() - INTERVAL '30 days';

-- name: GetExpiredPatientFiles :many
SELECT id, patient_id FROM patient_files
WHERE deleted_at < NOW() - INTERVAL '30 days';

-- name: GetExpiredSessions :many
SELECT id FROM sessions
WHERE deleted_at < NOW() - INTERVAL '30 days';

-- name: GetExpiredPatientNotes :many
SELECT id FROM patient_notes
WHERE deleted_at < NOW() - INTERVAL '30 days';

-- name: PurgePatientUser :execrows
DELETE FROM users
WHERE id = $1 AND role = 'PATIENT';

-- name: PurgePatientFile :execrows
DELETE FROM patient_files
WHERE id = $1;

-- name: PurgeSession :execrows
DELETE FROM sessions
WHERE id = $1;

-- name: PurgePatientNote :execrows
DELETE FROM patient_notes
WHERE id = $1;

-- name: PurgeOldAnalyticsEvents :execrows
DELETE FROM analytics_events
WHERE occurred_at < NOW() - INTERVAL '90 days';
