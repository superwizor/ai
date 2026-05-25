-- name: ListSupportedModalities :many
SELECT id, system_code, display_name, is_supported, modality_type
FROM modalities
WHERE is_supported = TRUE
ORDER BY display_name;

-- name: GetModalityByCode :one
SELECT id, system_code, display_name, is_supported, modality_type
FROM modalities
WHERE system_code = $1 AND is_supported = TRUE;
