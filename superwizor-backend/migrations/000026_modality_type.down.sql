-- Inverse of 000026. Drop the column first then the enum (Postgres
-- refuses to drop a type that's still referenced by a column).

ALTER TABLE modalities DROP COLUMN IF EXISTS modality_type;
DROP TYPE IF EXISTS modality_type;
