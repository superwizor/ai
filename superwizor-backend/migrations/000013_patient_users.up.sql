-- 000013: promote patient identity from free-form `working_alias` strings to
-- proper users rows with role='PATIENT'. Lets clinical-svc store structured
-- PII (first_name, last_name, ui_language) on patient_files participants.
--
-- Four changes happen here:
--
-- 1. Relax users NOT NULL on firebase_uid + email so patient rows can exist
--    WITHOUT an account. Therapist / admin rows still need both — enforced
--    via partial CHECK constraints that fire only for role != 'PATIENT'.
--
-- 2. Unique partial index on (therapist_id, working_alias) over active rows.
--    The therapist's UI uses working_alias as the visual identifier when
--    deciding which kartoteka to delete; uniqueness prevents the "two
--    patients named 'Anna'" ambiguity that would make a stray DELETE
--    target the wrong row. The index is partial (WHERE deleted_at IS NULL)
--    so a name freed by hard delete can be reused immediately.
--
-- 3. Flip patient_files.patient_id FK from ON DELETE RESTRICT to SET NULL.
--    Reason: the new DeletePatientUser RPC may wipe just the user row
--    (therapist wants to drop PII but keep the clinical record). With
--    RESTRICT PG would refuse the user delete while the patient_file
--    still references it. SET NULL leaves the file orphaned with
--    patient_id = NULL — handler clears patient_first_name / etc. on
--    re-read because the JOIN misses.
--
-- 4. Backfill: every existing patient_file without a patient_id gets a
--    fresh users row (role=PATIENT, first_name from working_alias,
--    ui_language inherited from the kartoteka's therapist). PL/pgSQL
--    loop so the insert + bind happens atomically per file — a CTE
--    INSERT ... RETURNING wouldn't preserve the back-reference to the
--    source patient_file row.

-- ---------- 1. relax users NOT NULLs + add partial CHECKs ----------
ALTER TABLE users ALTER COLUMN firebase_uid DROP NOT NULL;
ALTER TABLE users ALTER COLUMN email        DROP NOT NULL;

ALTER TABLE users ADD CONSTRAINT users_firebase_uid_required_for_non_patient
  CHECK (role = 'PATIENT' OR firebase_uid IS NOT NULL);
ALTER TABLE users ADD CONSTRAINT users_email_required_for_non_patient
  CHECK (role = 'PATIENT' OR email IS NOT NULL);

-- The pre-existing chk_users_email_format regex CHECK is only invoked
-- on non-NULL emails (PG semantics for CHECK + NULL operands), so it
-- stays as-is. UNIQUE indexes on firebase_uid + email default to
-- NULLS DISTINCT, so multiple patient rows with NULL keys don't
-- collide.

-- ---------- 2. unique (therapist_id, working_alias) over active rows ----------
CREATE UNIQUE INDEX ux_patient_files_therapist_alias
  ON patient_files (therapist_id, working_alias)
  WHERE deleted_at IS NULL;

-- ---------- 3. flip patient_files.patient_id FK to SET NULL ----------
ALTER TABLE patient_files DROP CONSTRAINT IF EXISTS patient_files_patient_id_fkey;
ALTER TABLE patient_files
  ADD CONSTRAINT patient_files_patient_id_fkey
  FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE SET NULL;

-- ---------- 4. backfill patient users for existing patient_files ----------
-- Uses pf.therapist_id to look up the kartoteka owner's ui_language so
-- the patient row inherits it. Falls back to 'pl' if the therapist row
-- is somehow missing (defensive — should never fire).
DO $$
DECLARE
  pf RECORD;
  new_uid UUID;
  therapist_lang VARCHAR(10);
BEGIN
  FOR pf IN
    SELECT id, working_alias, therapist_id
    FROM patient_files
    WHERE patient_id IS NULL AND deleted_at IS NULL
  LOOP
    SELECT ui_language INTO therapist_lang
    FROM users
    WHERE id = pf.therapist_id;

    INSERT INTO users (id, role, first_name, last_name, ui_language)
    VALUES (
      gen_random_uuid(),
      'PATIENT',
      COALESCE(NULLIF(pf.working_alias, ''), 'Patient'),
      '',
      COALESCE(therapist_lang, 'pl')
    )
    RETURNING id INTO new_uid;

    UPDATE patient_files SET patient_id = new_uid WHERE id = pf.id;
  END LOOP;
END $$;
