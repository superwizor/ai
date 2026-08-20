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

-- ── Guardrail evidence log: 24-month retention, NOT the GDPR sweep ───
--
-- guardrail_decisions is the MDR article 94 evidence pack (migration
-- 000085). It is deliberately NOT part of the 30/90-day GDPR erasure
-- above: it holds no personal data, and sweeping it on that cycle would
-- destroy the evidence three months into a 24-month obligation.
--
-- This query exists so the retention limit is enforced rather than
-- unbounded, and it is separate from every query above so the two
-- policies cannot be confused for one another. The interval below is
-- asserted by TestGuardrailDecisionsAreOutsideTheGDPRSweep — changing it
-- to a GDPR interval fails CI.

-- name: PurgeExpiredGuardrailDecisions :execrows
DELETE FROM guardrail_decisions
WHERE created_at < NOW() - INTERVAL '24 months';
