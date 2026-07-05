-- Client (patient) panel — docs/39. Every read is scoped by the
-- caller's patient_id (requireClientFileAccess) and, for therapist
-- content, by the explicit sharing markers (D2). No reports, no
-- therapist-private notes.

-- name: ClientListKartoteki :many
-- The client's kartoteki with per-file counters for the overview.
SELECT
    pf.id AS patient_file_id,
    (t.first_name || ' ' || t.last_name)::text AS therapist_name,
    COALESCE(o.legal_name, '')::text AS organization_name,
    (SELECT COUNT(*) FROM sessions s
      WHERE s.patient_file_id = pf.id AND s.deleted_at IS NULL
        AND s.shared_with_client_at IS NOT NULL
        AND s.client_hidden_at IS NULL)::int AS shared_sessions,
    (SELECT COUNT(*) FROM patient_notes n
      WHERE n.patient_file_id = pf.id AND n.deleted_at IS NULL
        AND n.kind <> 'CLIENT_NOTE'
        AND n.shared_with_client_at IS NOT NULL
        AND n.client_hidden_at IS NULL)::int AS shared_notes,
    (SELECT COUNT(*) FROM patient_notes n
      WHERE n.patient_file_id = pf.id AND n.deleted_at IS NULL
        AND n.kind <> 'CLIENT_NOTE'
        AND n.shared_with_client_at IS NOT NULL
        AND n.client_hidden_at IS NULL
        AND n.read_by_client_at IS NULL)::int AS unread_notes
FROM patient_files pf
JOIN users t ON t.id = pf.therapist_id
LEFT JOIN organizations o ON o.id = t.organization_id
WHERE pf.patient_id = $1 AND pf.deleted_at IS NULL
ORDER BY pf.created_at ASC;

-- name: ClientListSharedSessions :many
SELECT s.id, s.session_date, s.session_number, s.duration_seconds,
       s.shared_with_client_at,
       EXISTS(SELECT 1 FROM transcripts tr WHERE tr.session_id = s.id) AS has_transcript
FROM sessions s
WHERE s.patient_file_id = $1
  AND s.deleted_at IS NULL
  AND s.shared_with_client_at IS NOT NULL
  AND s.client_hidden_at IS NULL
ORDER BY s.session_date DESC, s.session_number DESC;

-- name: ClientGetSharedSession :one
-- Session + owning kartoteka's patient for the transcript authz:
-- the handler checks patient_id == caller AND shared marker.
SELECT s.id, s.patient_file_id, s.session_date, s.session_number,
       s.duration_seconds, s.shared_with_client_at, s.deleted_at,
       pf.patient_id
FROM sessions s
JOIN patient_files pf ON pf.id = s.patient_file_id
WHERE s.id = $1 AND s.deleted_at IS NULL;

-- name: ClientListVisibleNotes :many
-- Therapist notes shared with the client + the client's own notes.
-- Excludes items the client dismissed from their panel (client_hidden_at);
-- a client's own CLIENT_NOTE is never hidden (they hard-delete instead).
SELECT * FROM patient_notes
WHERE patient_file_id = $1
  AND deleted_at IS NULL
  AND client_hidden_at IS NULL
  AND (shared_with_client_at IS NOT NULL OR kind = 'CLIENT_NOTE')
ORDER BY created_at DESC;

-- name: CreateClientNote :one
-- kind=CLIENT_NOTE, author_role=PATIENT (chk_patient_notes_author).
-- therapist_id is the counterparty (kartoteka owner). $7=true stamps
-- sent_to_therapist_at (deliver on create); false saves a PRIVATE
-- draft the therapist can't see (000068).
INSERT INTO patient_notes (
    patient_file_id, therapist_id, kind, author_role,
    title_ciphertext, title_encrypted_dek, text_ciphertext, text_encrypted_dek,
    sent_to_therapist_at
) VALUES ($1, $2, 'CLIENT_NOTE', 'PATIENT', $3, $4, $5, $6,
    CASE WHEN $7::bool THEN now() ELSE NULL END)
RETURNING *;

-- name: MarkClientNoteSentToTherapist :one
-- Deliver a saved draft. Idempotent — a delivered note keeps its
-- first timestamp.
UPDATE patient_notes
SET sent_to_therapist_at = COALESCE(sent_to_therapist_at, now()),
    updated_at = now()
WHERE id = $1 AND kind = 'CLIENT_NOTE' AND deleted_at IS NULL
RETURNING *;

-- name: MarkNoteReadByClient :exec
UPDATE patient_notes SET read_by_client_at = now()
WHERE id = $1 AND read_by_client_at IS NULL;

-- name: MarkKartotekaClientNotesReadByTherapist :exec
-- Auto-mark when the therapist opens the kartoteka notes list — the
-- badge is edge-triggered, not an inbox.
UPDATE patient_notes SET read_by_therapist_at = now()
WHERE patient_file_id = $1 AND kind = 'CLIENT_NOTE'
  AND sent_to_therapist_at IS NOT NULL
  AND read_by_therapist_at IS NULL AND deleted_at IS NULL;

-- name: SetSessionSharedWithClient :one
-- shared=true stamps now() once (idempotent); false clears.
UPDATE sessions
SET shared_with_client_at = CASE
      WHEN $2::bool THEN COALESCE(shared_with_client_at, now())
      ELSE NULL END,
    updated_at = now()
WHERE id = $1 AND deleted_at IS NULL
RETURNING id, shared_with_client_at;

-- name: SetNoteSharedWithClient :one
UPDATE patient_notes
SET shared_with_client_at = CASE
      WHEN $2::bool THEN COALESCE(shared_with_client_at, now())
      ELSE NULL END,
    updated_at = now()
WHERE id = $1 AND deleted_at IS NULL AND kind <> 'CLIENT_NOTE'
RETURNING id, shared_with_client_at;

-- name: CountUnreadClientNotesForKartoteka :one
-- Therapist-side badge.
SELECT COUNT(*)::int FROM patient_notes
WHERE patient_file_id = $1 AND kind = 'CLIENT_NOTE'
  AND sent_to_therapist_at IS NOT NULL
  AND read_by_therapist_at IS NULL AND deleted_at IS NULL;

-- name: GetPatientUserEmailForFile :one
-- docs/39 PR9: the client-panel account e-mail for a kartoteka. Only an
-- attached, ACTIVE patient user with an e-mail can receive the PHI-free
-- "new item in your panel" signal — pseudonymous kartoteki skip it.
-- PR12 also returns the client's users.id so the ITEM_SHARED event can
-- address the recipient's Firestore inbox for live web-panel refresh.
SELECT u.id AS patient_id, u.email, u.ui_language
FROM patient_files pf
JOIN users u ON u.id = pf.patient_id
WHERE pf.id = $1 AND u.is_active AND u.email IS NOT NULL;

-- name: GetUserEmailForNotify :one
-- docs/39 PR9: therapist recipient for client_note_received.
SELECT email, ui_language FROM users
WHERE id = $1 AND is_active AND email IS NOT NULL;

-- name: GetClientNoteForDelete :one
-- docs/39 PR13: fetch a note for the hard-delete authz check. Handler
-- verifies patient_file_id belongs to the caller and kind = CLIENT_NOTE.
SELECT id, patient_file_id, kind, author_role
FROM patient_notes
WHERE id = $1 AND deleted_at IS NULL;

-- name: HardDeleteClientNote :execrows
-- docs/39 PR13: the client removes their OWN note everywhere (including
-- from the therapist if it was sent). Guarded to CLIENT_NOTE so a therapist
-- note can never be destroyed through this path. Returns rows affected so
-- the handler can 404 on a no-op.
DELETE FROM patient_notes
WHERE id = $1 AND kind = 'CLIENT_NOTE';

-- name: HideSessionFromClient :execrows
-- docs/39 PR13: dismiss a shared session from the client's panel only.
UPDATE sessions
SET client_hidden_at = now(), updated_at = now()
WHERE id = $1 AND deleted_at IS NULL
  AND shared_with_client_at IS NOT NULL
  AND client_hidden_at IS NULL;

-- name: HideNoteFromClient :execrows
-- docs/39 PR13: dismiss a shared THERAPIST note from the client's panel
-- only. kind <> CLIENT_NOTE so a client's own note can't be hidden (they
-- hard-delete instead).
UPDATE patient_notes
SET client_hidden_at = now(), updated_at = now()
WHERE id = $1 AND deleted_at IS NULL
  AND kind <> 'CLIENT_NOTE'
  AND shared_with_client_at IS NOT NULL
  AND client_hidden_at IS NULL;
