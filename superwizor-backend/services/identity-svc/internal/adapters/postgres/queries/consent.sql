-- name: RecordConsent :one
INSERT INTO consent_records (
    user_id, consent_type, granted, consent_version, ip_address, user_agent
) VALUES (
    $1, $2, $3, $4, $5, $6
)
RETURNING *;

-- name: GetConsentHistory :many
SELECT * FROM consent_records
WHERE user_id = $1
ORDER BY recorded_at DESC;

-- name: GetLatestConsent :one
SELECT * FROM consent_records
WHERE user_id = $1 AND consent_type = $2
ORDER BY recorded_at DESC
LIMIT 1;
