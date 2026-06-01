# 22 — Patient Notes + "Plan działania → Pacjent"

**Status:** Design approved (2026-05-31). Flutter UX prototype on
`feat/patient-notes` (local-only, no backend yet). Backend NOT implemented.
**Branch:** `feat/patient-notes`
**Related:** clinical-svc (notes + report), notification-svc (email/Resend),
ai-pipeline-svc llm-worker (report markdown).

---

## 1. Problem & current state

The Kartoteka "Dodaj notatkę" feature is **local-only**: notes live in the
Flutter Hive `meta` box (`patient_notes` key, see
`lib/providers/patient_notes_provider.dart`) and **never reach the backend**.
Consequences: data lost on reinstall/device change, no cross-device sync, no
backup, invisible to RODO export/erase.

There is **no** note table, RPC, proto, or handler in clinical-svc. The only
near-match, `patient_files.private_therapist_notes TEXT`, is a *single* free
field on the patient file (edited via `UpdatePatientFile`), not a multi-note
list.

New requirement on top: from a session's report, extract the **"Plan działania
klienta"** and let the therapist **send it to the patient by email** (with a
save-only option, a patient-email check, and an editable email template).

---

## 2. Decisions (locked)

| Topic | Decision |
|---|---|
| Notes persistence | Move from Hive-only to **clinical-svc** (server CRUD); Hive becomes an offline/SWR cache. |
| Action-plan extraction | **Heuristic, server-side** — parse the report Markdown by heading; no LLM/prompt change. |
| Email template store | **DB table `email_templates` (JSONB) + `go:embed` fallback** in notification-svc. |
| Notes at rest | **Envelope-encrypted** (ciphertext + encrypted DEK), like transcripts. |

---

## 3. Backend design (NOT yet implemented)

### 3.1 Schema
```sql
CREATE TABLE patient_notes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  patient_file_id    UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
  therapist_id       UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
  kind               TEXT NOT NULL DEFAULT 'FREE_NOTE',   -- FREE_NOTE | ACTION_PLAN
  source_session_id  UUID REFERENCES sessions(id) ON DELETE SET NULL,
  title_ciphertext   BYTEA NOT NULL, title_encrypted_dek  BYTEA NOT NULL,
  text_ciphertext    BYTEA NOT NULL, text_encrypted_dek   BYTEA NOT NULL,
  sent_to_patient_at TIMESTAMPTZ, sent_to_email TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
CREATE INDEX idx_patient_notes_file
  ON patient_notes(patient_file_id, created_at DESC) WHERE deleted_at IS NULL;

CREATE TABLE email_templates (
  template_key TEXT NOT NULL, locale TEXT NOT NULL,
  content JSONB NOT NULL,            -- {subject, body_html, body_text}
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (template_key, locale)
);
```
`ON DELETE CASCADE` from `patient_files` makes the existing
`DeletePatientFile`/`DeletePatientUser` RODO fan-out erase notes automatically.

### 3.2 clinical-svc RPCs (`clinical/v1`)
- `GetActionPlanDraft(session_id) → {suggested_title, suggested_text,
  patient_has_email, patient_email_masked}` — runs the heuristic extractor on
  the decrypted report; resolves patient email via
  `patient_file → patient_id → users.email`.
- `CreatePatientNote / ListPatientNotes / UpdatePatientNote / DeletePatientNote`
  — CRUD, mirroring the PatientFile handlers; authz = note's
  `patient_file.therapist_id == ctx user`.
- `SavePatientNote(…, send_to_patient)` — persists; if `send_to_patient`:
  resolve email → no email → `FailedPrecondition "PATIENT_EMAIL_MISSING"`
  (note still saved); else call notification-svc, stamp `sent_*`, write
  `audit_events`.

### 3.3 notification-svc RPC (`notification/v1`)
- `SendActionPlanEmail(to_email, patient_display_name, therapist_display_name,
  action_plan_text, locale, session_date)` — load `email_templates`
  (`template_key='action_plan'`) with embed fallback, render `{key}`
  placeholders, send via existing Resend `Sender`, write `notification_deliveries`
  with idempotency key `note_id:action_plan_sent`.

### 3.4 Heuristic extractor (server-side, Go)
Match report Markdown headings (case/accent-insensitive, `##`/`###`), priority:
`Plan działania klienta` → `Plan działania` → `Propozycje interwencji` →
`Ustalone z klientem zadania`/summary-point-4 → empty. Return the text from the
matched heading to the next same-or-higher heading. Never blocks.

### 3.5 Compliance
First **outbound disclosure of clinical content to a patient**: audit every
send; idempotent delivery; Resend over TLS; never log bodies; recommend a
"patient consents to email" flag + a template footer/disclaimer.

---

## 4. Flutter UX (PROTOTYPE — implemented first, local-only)

Until the backend lands, the app keeps using the local Hive `PatientNotesProvider`
and **simulates** the send.

- **`lib/utils/action_plan_extractor.dart`** — client-side heuristic mirroring
  §3.4, returns `{title, text}` from the report Markdown.
- **`lib/screens/note_editor_screen.dart`** — the note editor extracted from
  `client_details_screen.dart` and made reusable + public (`NoteEditorScreen`),
  with new params: `initialTitle`, `initialText`, `actionPlanMode`,
  `sourceSessionId`, `patientEmail`.
  - Normal mode: single "Zapisz" (unchanged behaviour).
  - `actionPlanMode`: two actions — **"Zapisz"** (save only) and
    **"Zapisz i wyślij"** (save + send).
- **`report_screen.dart`** — new button **"Wyślij Plan Działania do Pacjenta"**
  → run extractor on the report Markdown → push `NoteEditorScreen` prefilled,
  `actionPlanMode: true`, `sourceSessionId`, `patientFileId` from
  `SessionDto.patientFileId`.
- **Send flow (simulated):** "Zapisz i wyślij" →
  - if patient email unknown/empty → **warning**: "Brak adresu e-mail pacjenta…".
  - else → confirm dialog (masked email) → save + toast "Zapisano i wysłano
    (symulacja)". A clearly-labelled prototype scaffold toggles the
    has-email/no-email branch so both can be exercised before the backend
    resolves the real email.

When the backend lands: swap the Hive provider for a `ClinicalNotesRepository`
(SWR over Hive) + call the real RPCs; one-time push of any local-only notes to
the server so nothing is lost.

---

## 5. Work breakdown
1. **Flutter UX prototype** (this branch, local-only) — extractor + reusable
   editor + report button + simulated send. ← *current step*
2. Backend: `patient_notes` + notes CRUD + `GetActionPlanDraft` + `SavePatientNote`.
3. Backend: notification-svc `SendActionPlanEmail` + `email_templates` + seed.
4. Flutter: server-backed notes repo + real send + local→server migration.
5. Tests (handler round-trips, no-email path, idempotent send, RODO cascade) +
   e2e + deploy.
