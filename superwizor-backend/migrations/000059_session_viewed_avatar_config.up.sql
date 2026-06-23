-- ============================================================
-- 000059 — Backend-synced preferences: viewed reports + avatar
-- ============================================================
--
-- report_viewed_at (sessions): Timestamp when the therapist first
-- opened the completed report. NULL = unviewed ("nowy raport" badge
-- in Flutter). Not PHI — a UX timestamp. Replaces the Flutter-local
-- SharedPreferences-based viewed_reports tracking so the state syncs
-- across devices.
--
-- avatar_config (patient_files): Per-kartoteka avatar customization
-- (custom label + color index). JSONB for flexibility:
--   {"label": "AK", "color": 3}
-- NULL = no customization (auto-initials + default teal). Replaces
-- the Flutter-local SharedPreferences-based patient_avatar_ keys.

ALTER TABLE sessions ADD COLUMN report_viewed_at TIMESTAMPTZ;

ALTER TABLE patient_files ADD COLUMN avatar_config JSONB;
