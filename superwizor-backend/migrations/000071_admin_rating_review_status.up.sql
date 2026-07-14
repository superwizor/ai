-- 000071: admin feedback dashboard — review status column.
--
-- Adds an admin-review-status flag to report_ratings so the admin
-- dashboard can track which feedback entries have been actioned.
-- Default 'pending' = unreviewed; 'done' = admin marked as handled.
--
-- No index added: the admin dashboard query already uses
-- idx_report_ratings_therapist for ordering and the volume of ratings
-- is low enough that a sequential scan on the new column is fine.

ALTER TABLE report_ratings
    ADD COLUMN admin_review_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (admin_review_status IN ('pending', 'done'));

COMMENT ON COLUMN report_ratings.admin_review_status IS
    'Admin review status for the feedback dashboard. '
    'pending = unreviewed/to-do, done = admin marked as actioned.';
