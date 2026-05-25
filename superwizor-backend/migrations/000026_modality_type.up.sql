-- Adds a `modality_type` discriminator to the modalities catalog.
--
-- Why: llm-worker generates speaker labels ("Osoba 1", "Osoba 2",
-- ...) for every session. Now that the catalog mixes clinical
-- modalities (CBT, DBT, psychodynamic, …) with non-clinical
-- modalities (ICF/GROW coaching), the label vocabulary needs to
-- branch. Therapy sessions get "Terapeuta" + "Pacjent"; coaching
-- sessions get "Trener" + "Klient" (Polish; English equivalents
-- "Therapist"/"Patient" + "Coach"/"Client"). Multi-participant
-- sessions get a numeric suffix on the second-plus speaker of the
-- same role ("Pacjent 2", "Coach 3", …) — see
-- `pkg/i18n/rolelabels`. Non-dyadic roles (couple_partner,
-- family_member_*, third_party, unknown, filler) keep the existing
-- "Osoba N" / "Person N" naming.
--
-- The enum has just two values today; intentionally narrow. A
-- third "group" or "supervision" value can be added later via
-- ALTER TYPE ... ADD VALUE (Postgres ≥ 12 is non-blocking).
--
-- Backfill: every existing modality except the ICF/GROW coaching
-- row is treated as therapy. We match by `system_code` — the
-- canonical stable identifier on this table (display_name is
-- localized + may drift). Today only `COACH` qualifies; future
-- coaching modalities should set modality_type at INSERT time.

CREATE TYPE modality_type AS ENUM ('therapy', 'coaching');

ALTER TABLE modalities
    ADD COLUMN modality_type modality_type NOT NULL DEFAULT 'therapy';

UPDATE modalities
SET    modality_type = 'coaching'
WHERE  system_code = 'COACH';

-- Drop the default once backfill completes — future inserts MUST
-- pick a type explicitly (catches the "forgot to set it" bug at
-- INSERT time rather than at first-session rendering).
ALTER TABLE modalities ALTER COLUMN modality_type DROP DEFAULT;
