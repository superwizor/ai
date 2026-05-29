-- Add a `reason` column to audit_events so admin mutations (block org,
-- reset tokens, change plan, edit user) can capture the operator's
-- rationale alongside the structured payload in `metadata`.
--
-- Reference: docs/18_WEB_APP_DESIGN.md §13.7, §13.8 (every admin form
-- has a required reason field, ≥10 chars validated at handler level).
--
-- NULL-allowed at the schema level so historical rows (created before
-- this column existed) stay valid. New admin RPCs enforce the
-- requirement in Go; non-admin code paths leave it NULL.

ALTER TABLE audit_events
    ADD COLUMN reason TEXT;

COMMENT ON COLUMN audit_events.reason IS
    'Operator-supplied rationale for admin mutations (SUPERWIZOR_ADMIN). '
    'NULL for non-admin events. Handler-level CHECK requires >=10 chars '
    'when actor role is SUPERWIZOR_ADMIN.';
