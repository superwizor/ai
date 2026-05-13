# Flutter integration changelog — clinical-svc, 2026-05-12

> Branch: `feat/clinical-svc-update`. Deployed to staging as `clinical-svc-5e4b83b` (image `:5e4b83be…`). E2E suite green on staging (5/5 tests, full create→audio→STT→LLM→cascade flow). Merged to main same day.

This file is the **single reference** for the Flutter team after pulling this branch. Read it before touching kartoteka, session, or transcript screens. Everything below is observable through the gRPC API — the underlying schema is documented in `02_clinical-svc.md` and `migrations/0000{11,12,13,14}_*.up.sql` if you need more.

Order is: **(a) breaking** → **(b) new** → **(c) behavior changes** → **(d) what to render differently**. Each section says what to do AND what not to do.

---

## Quick checklist for the Flutter PR

- [ ] Regenerate dart proto stubs (`lib/generated/clinical/v1/clinical.pb.dart` etc.)
- [ ] `CreatePatientFile` form: add a required `patient_first_name` input; optional `patient_last_name`; optional language picker (default to therapist's UI language)
- [ ] Validate `working_alias` uniqueness against the therapist's active kartoteki list before submit
- [ ] Map `AlreadyExists` gRPC errors to a friendly "alias in use" / "permanent delete" copy
- [ ] Kartoteka edit screen: disable the **modality** picker once the kartoteka exists
- [ ] Re-enable modality display from `modality_code` on Get/List screens (it's no longer empty)
- [ ] Wire `UpdatePatientUser` to a new "Edit patient info" panel
- [ ] Wire `DeletePatientUser` as a RODO "erase patient" action — distinct from "delete kartoteka"
- [ ] Wire `UpdateSession` (rename) and `DeleteSession` to the session row context menu
- [ ] Read-only transcript view: switch to `Transcript.turns` (speaker-grouped); keep `Transcript.segments` only on the label-edit screen
- [ ] Delete confirmations must say **permanently** — these are RODO hard deletes, not soft

---

## (a) Breaking — read this first

### CreatePatientFile now requires `patient_first_name`

```proto
message CreatePatientFileRequest {
    // existing fields…
    string patient_first_name    = 8;  // REQUIRED — empty string rejected
    string patient_last_name     = 9;  // optional
    string patient_language_code = 10; // optional; defaults to therapist's ui_language
}
```

Submitting without `patient_first_name` returns `InvalidArgument: "patient_first_name required"`. The Flutter form needs a first-name input; everything else can be optional. **Last name** is the patient's surname (e.g. "Kowalska"); leave empty if the therapist doesn't know it. **Language code** is BCP-47-ish 2-3 char (`pl`, `en`, `de`) — if you don't show a picker, leave it empty and the server inherits from the therapist's `users.ui_language`.

### DeletePatientFile is now HARD delete

Previously this was a soft delete (`deleted_at = now()`). Since migration 000012 and commit 1a55c37, the same RPC performs a permanent cascade-delete:

```
patient_files → audio_uploads
              → sessions → transcripts → segments
                         → reports     → hitop_measurements
              → (since 000013) the paired patient user row
```

**No recovery once committed.** Confirmation copy must say "permanent" — "Delete kartoteka and all sessions/reports? This cannot be undone."

### `working_alias` is now unique per therapist for active rows

Migration 000013 added `UNIQUE INDEX ux_patient_files_therapist_alias ON patient_files (therapist_id, working_alias) WHERE deleted_at IS NULL`. Hitting it returns `AlreadyExists` from both `CreatePatientFile` and `UpdatePatientFile`. The error message includes the offending alias:

```
working_alias "Marek K." already used by another active kartoteka
```

**UX**: validate against the locally cached patient list before submit, but **always** handle `AlreadyExists` from the server as a fallback (cache may be stale).

### Modality is IMMUTABLE after Create

`modality_code` is set at Create time and cannot be changed. `UpdatePatientFileRequest` deliberately excludes it. See the proto comment at `clinical.proto::PatientFile.modality_id` for the rationale (sessions/reports were analyzed under the original modality; switching mid-process would re-frame past clinical work).

**UX**: gray out / disable the modality picker on the kartoteka edit screen. The recovery path for a wrong pick is `DeletePatientFile` + recreate.

---

## (b) New RPCs

### `UpdatePatientUser`

Edit the patient's PII (first name / last name / language) without touching the kartoteka's clinical fields (alias, complaint, notes).

```proto
rpc UpdatePatientUser(UpdatePatientUserRequest) returns (PatientFile);

message UpdatePatientUserRequest {
    string patient_file_id = 1;  // kartoteka id (NOT the patient user id)
    string first_name      = 2;  // empty = leave alone
    string last_name       = 3;  // empty = leave alone
    string language_code   = 4;  // empty = leave alone
}
```

- Identified by `patient_file_id` so authz uses the standard therapist-ownership check on the parent kartoteka.
- Empty strings mean "don't change" (server-side COALESCE/NULLIF). To clear a field, this RPC currently won't help — you'd need a separate "clear field" flow, which doesn't exist yet.
- Returns the refreshed `PatientFile` with the updated user fields + everything else unchanged, so the Flutter side can re-render in one round-trip.

**UX placement**: a separate "Edit patient info" section in the kartoteka edit screen, alongside the existing `UpdatePatientFile` (working_alias, initial_complaint, private_therapist_notes, is_process_closed).

### `DeletePatientUser` — RODO right-to-erasure

```proto
rpc DeletePatientUser(DeletePatientUserRequest) returns (google.protobuf.Empty);

message DeletePatientUserRequest {
    string patient_file_id = 1;  // kartoteka id, NOT the user id
}
```

**This is the "patient asked to be forgotten" action.** Wipes the patient user row, which cascades through every kartoteka they're attached to → sessions → transcripts → reports → hitop. Identified by `patient_file_id` so authz is the standard therapist-ownership check.

**Important UX distinction**:

| Action | Meaning | What disappears |
|---|---|---|
| `DeletePatientFile` | "I'm done with this kartoteka" | One kartoteka and its sessions/transcripts/reports |
| `DeletePatientUser` | "Patient asked to be forgotten (RODO)" | The patient + **every** kartoteka they're attached to (today: same person = same user row across kartoteki) + all sessions/transcripts/reports |

Confirmation copy should differ. For `DeletePatientUser` use stronger language: "Permanently erase this patient and ALL their clinical data?" Both are unrecoverable.

### `UpdateSession` — rename a session

```proto
rpc UpdateSession(UpdateSessionRequest) returns (Session);

message UpdateSessionRequest {
    string session_id = 1;
    string name = 2;  // required; empty rejected; max 255 chars; whitespace trimmed server-side
}
```

Today only `name` is mutable. Future patches will extend this for `session_date` correction etc. — add fields here, not new RPCs.

**Default name** at session create is `"<modality display_name> <session_number>"` (e.g. "Cognitive Behavioral Therapy 3"). The therapist can rename via this RPC.

**UX**: long-press / context menu on session row → "Rename" → modal with text input → submit. Treat `InvalidArgument` (empty / too long) as inline validation errors.

### `DeleteSession` — hard delete a single session

```proto
rpc DeleteSession(DeleteSessionRequest) returns (google.protobuf.Empty);

message DeleteSessionRequest {
    string session_id = 1;
}
```

Hard delete with cascade through transcripts/reports/hitop. Publishes `session.deleted` Pub/Sub event so notification-svc can wipe the Firestore `session_states/{sessionId}` mirror + inbox notifications — Flutter doesn't need to do that side; subscribe to the existing Firestore stream and rows will disappear.

`NotFound` if either the session doesn't exist or belongs to a different therapist (same code for both, to avoid ID enumeration).

---

## (c) Behavior changes on existing RPCs

### `modality_code` now populated on every read

Previously: `GetPatientFile`, `ListPatientFiles`, `UpdatePatientFile`, `UpdatePatientUser` returned `modality_code = ""` (only `CreatePatientFile` set it correctly). The fix (commit 662b9db) JOINs the modalities table on read so every response carries it.

**UX**: if Flutter currently hides the modality on read paths or falls back to `modality_id`, switch to displaying `modality_code` (it's the human-readable system_code like `"CBT"`, `"PSYCHO"`, `"UNIV"`).

### `PatientFile` carries patient PII fields

```proto
message PatientFile {
    // existing fields 1-15…
    string patient_first_name    = 16;
    string patient_last_name     = 17;
    string patient_language_code = 18;
}
```

Populated by JOIN on the paired `users(role='PATIENT')` row. Returns empty strings if the patient user was wiped via `DeletePatientUser` and the kartoteka was somehow left orphan (rare; only possible on rows from before migration 000014 flipped the FK to CASCADE). Renderer should treat empty string as "unknown" rather than throwing.

### Idempotency on `CreatePatientFile` is **not yet enforced**

`CreatePatientFileRequest.idempotency_key` is currently ignored server-side. Replaying the same request creates a new kartoteka with a new ID — or, post-migration 000013, hits the `working_alias` unique index and returns `AlreadyExists`. There's a tracked bug for this; flutter should treat the field as aspirational and not rely on it for retries yet.

---

## (d) New: speaker-grouped transcript view

`Transcript` now carries both the existing per-chunk segments AND a new speaker-grouped view:

```proto
message Transcript {
    string id = 1;
    repeated TranscriptSegment segments = 2;  // unchanged — per-chunk granularity
    repeated SpeakerTurn turns = 3;           // NEW — what the read view should bind to
}

message SpeakerTurn {
    int32  speaker_tag      = 1;
    string speaker_label    = 2;  // e.g. "Osoba 1", localized
    int32  start_offset_ms  = 3;
    int32  end_offset_ms    = 4;
    string text             = 5;  // joined chunks with single spaces
    int32  segment_count    = 6;  // for future "expand to raw chunks" UI
    float  confidence_avg   = 7;
}
```

A **turn** is a contiguous span of same-speaker segments. Server-side, `clinical-svc/internal/grouping/GroupSegmentsIntoTurns` runs the collapse on every `GetSessionDetails` response. Algorithm: walk segments in `start_offset_ms` order; start a new turn on `speaker_tag` change OR `speaker_label` change; join text with single spaces; weight confidence by segment count.

**Display contract** (this is the format the backend group is built to support):

```
[Osoba 1 · 00:00:05] Powiedziałem mu że nie zgadzam się z tym jak to
                     teraz wygląda. To jest coś co od dawna mnie boli.
[Osoba 2 · 00:00:42] Aha. Rozumiem.
[Osoba 1 · 00:00:45] I dlatego myślę że trzeba to zmienić.
```

- `speaker_label` is the localized label (`"Osoba 1"`, `"Osoba 2"` in Polish; English maps to `"Person 1"` etc., see `pkg/i18n/speakerlabels` server-side).
- Format `start_offset_ms` client-side: `Duration(milliseconds: ms).toString()` works but the `0:00:05.000000` shape is ugly — use a small helper:

  ```dart
  String fmtOffset(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours;
    final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
    final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
  }
  ```

### When to use `segments` vs `turns`

| Screen | Use |
|---|---|
| Read-only transcript display (default) | `turns` |
| "Edit speaker labels" screen (UpdateSpeakerLabels) | `segments` — needs per-chunk granularity to drive the per-tag rename UI |
| Search / find-in-transcript | `turns` is friendlier (longer matches); use `segments` if you want per-chunk navigation |

### Empty / unlabeled edge cases

- **`speaker_tag == 0`**: STT placeholder before LLM speaker inference completes. `speaker_label` will be empty. Render as "Unknown speaker" or hide the speaker tag entirely until the LLM stage finishes (poll `GetSessionDetails` — when `speaker_label_mapping` is populated, the segments + turns will have proper tags too).
- **Empty turn text**: defensive output if every contributing segment failed decrypt (KMS rotation case). The turn still exists with the right time range and segment_count; just no text. Render as "(no text — segments unreadable)" or skip silently.

---

## Reference

- Proto: `proto/clinical/v1/clinical.proto`
- Backend handlers: `services/clinical-svc/internal/adapters/grpc/`
- Grouping algorithm: `services/clinical-svc/internal/grouping/turns.go` (with 12 unit tests in `turns_test.go`)
- Migrations: `migrations/00001{1,2,3,4}_*.up.sql`
- E2E coverage: `tests/e2e/full_session_test.go` (full chain + cascade) + `tests/e2e/patient_lifecycle_test.go` (CRUD without audio)

For deeper context on each change, the commit messages on `feat/clinical-svc-update` are detailed:
- `1a55c37` — session rename + hard-delete CRUD
- `c74fa9d` — patient user records (first/last/language)
- `3fd4f20` — DeletePatientUser RODO erasure
- `662b9db` — expose modality_code on read paths
- `d4e74c5` — modality immutability docs
- `5e4b83b` — speaker turn grouping

Ping the backend team if anything below the gRPC surface isn't behaving as documented — the E2E suite catches most regressions but staging data can drift.
