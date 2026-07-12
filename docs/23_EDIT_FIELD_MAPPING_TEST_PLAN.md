---
type: Technical Design
title: "Plan: test every editable field's round-trip to the backend"
description: "Two recent bugs were the same shape: an editable value saved server-side but the client read-back mapping dropped it, so the field reverted on re-open."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/23_EDIT_FIELD_MAPPING_TEST_PLAN.md
tags: []
timestamp: 2026-06-02T15:17:46+02:00
---

# Plan: test every editable field's round-trip to the backend

## Why

Two recent bugs were the *same shape*: an editable value saved server-side
but the **client read-back mapping dropped it**, so the field reverted on
re-open.

- **Session rename** — `sessions.name` was mapped into `Session.modality`
  and never into `Session.name` (the field the card shows). Persisted to DB,
  invisible in UI. (Fixed: `798f672`.)
- **Patient e-mail** — under investigation; same suspected class.

The unit/e2e gaps that let these through: tests asserted *one* read path
(e.g. `GetPatientFile`) but the UI reads from *another* (`ListPatientFiles`),
and **no test asserted the Dart proto→model→UI mapping** at all.

This plan closes both gaps: (A) backend e2e asserts **every read RPC** a
screen consumes, and (B) **Dart unit tests** assert proto→DTO→model→widget
mapping for every editable field, so a dropped field fails in CI.

## A. Backend e2e — every editable field, through every read path

Extend `tests/e2e/patient_lifecycle_test.go` (+ a new `session_edit_test.go`)
so each editable field is written, then read back through **all** RPCs the
app uses for that entity.

| Entity | Write RPC | Editable fields | Read-back RPCs to assert |
|---|---|---|---|
| Patient file | `UpdatePatientUser` / `CreatePatientFile` | first_name, last_name, patient_email, language_code | `GetPatientFile` **and** `ListPatientFiles` |
| Patient file | `UpdatePatientFile` | working_alias, initial_complaint, private_therapist_notes, is_process_closed, process_type | `GetPatientFile` **and** `ListPatientFiles` |
| Session | `UpdateSession` | name (title) | `GetSessionDetails` **and** `ListSessions` |
| Patient note | `UpdatePatientNote` | title, text | `ListPatientNotes` |

Rule: **assert through the LIST RPC too** — list and get use different proto
mappers (`toProtoPatientFileFromListJoinRow` vs `…FromJoinRow`); a field can
be present in one and missing in the other (exactly the e-mail risk).
Done for e-mail in `80eaaeb`; replicate for the rest.

## B. Dart unit tests — proto → DTO → model → widget mapping

New `flutter-app/superwizor/test/mapping/`:

1. **`session_dto_mapping_test.dart`** — build a `clinical_pb.Session` with a
   non-default `name`; assert `SessionDto.fromProto(...).toModel().name ==`
   that value (the regression that bit us). Repeat for every field the card
   reads (`name`, `modality`, `status`, `durationSeconds`, `sessionNumber`).
   Round-trip through `toJson`/`fromJson` and assert no field is dropped by
   the Hive cache layer.

2. **`patient_dto_mapping_test.dart`** — `clinical_pb.PatientFile` with
   `patientEmail`, `patientFirstName`, `patientLastName`, `patientLanguageCode`,
   `modalityCode`; assert `PatientDto.fromProto(...).toModel()` carries each;
   assert `toJson`→`fromJson` preserves `email` (cache round-trip).

3. **`patient_provider_mapping_test.dart`** — the `_fetchDirectFallback`
   inline `Session(...)`/`Patient(...)` builders are a *second* mapping that
   must stay in lockstep with the DTO. Assert it sets the same fields (this
   is where a "fix the DTO but forget the fallback" bug hides).

4. **Editable-field contract test** — a single table-driven test listing every
   `(proto field) -> (model getter)` pair the edit forms read/write; fail if
   any model getter returns the default when the proto field was set. This is
   the guard that would have caught BOTH bugs.

## C. Widget tests for the edit forms (optional, higher value-per-line)

`test/widgets/edit_patient_modal_test.dart`,
`test/widgets/session_options_sheet_test.dart`:
pump the widget with a model that has every field populated, assert each
controller pre-fills from the model; enter new values, tap save, and assert
the fake notifier received the expected RPC args (incl. `patientEmail`,
session `name`). Catches "form doesn't pass the field to the RPC" and
"form doesn't pre-fill from the model".

## D. CI wiring

- Dart mapping/widget tests run in the existing `flutter test` CI step (fast,
  no backend) — these are the real regression guard.
- e2e read-path assertions run in the manual/nightly e2e (needs gcloud + prod).

## Sequencing

1. Land the Dart mapping tests (B1–B4) first — they're fast, hermetic, and
   would have caught both shipped bugs. **Do these even before the next bug
   is confirmed.**
2. Backfill the e2e LIST assertions (A) per entity.
3. Add the widget tests (C) for the two edit surfaces.
