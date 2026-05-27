-- name: GetAddressByID :one
SELECT * FROM addresses WHERE id = $1;

-- name: CreateAddress :one
INSERT INTO addresses (
    country_code, region, city, postal_code, street_line,
    building_number, unit_number, directions
) VALUES (
    sqlc.arg(country_code),
    sqlc.narg(region),
    sqlc.arg(city),
    sqlc.arg(postal_code),
    sqlc.arg(street_line),
    sqlc.arg(building_number),
    sqlc.narg(unit_number),
    sqlc.narg(directions)
)
RETURNING *;

-- name: UpdateAddress :one
-- Selective update — pass NULL on any narg to keep the existing value.
UPDATE addresses SET
    country_code    = COALESCE(sqlc.narg(country_code), country_code),
    region          = COALESCE(sqlc.narg(region), region),
    city            = COALESCE(sqlc.narg(city), city),
    postal_code     = COALESCE(sqlc.narg(postal_code), postal_code),
    street_line     = COALESCE(sqlc.narg(street_line), street_line),
    building_number = COALESCE(sqlc.narg(building_number), building_number),
    unit_number     = COALESCE(sqlc.narg(unit_number), unit_number),
    directions      = COALESCE(sqlc.narg(directions), directions)
WHERE id = sqlc.arg(id)
RETURNING *;
