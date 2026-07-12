---
type: Agent Context
title: "Testing — End-to-End Scenarios"
description: "Verify the system works as a whole, not just per-service. E2E tests exercise the real flow: Flutter-style gRPC call → service → DB → Pub/Sub → worker → DB → ..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/agents/09_testing.md
tags: [testing, agents]
timestamp: 2026-05-21T21:29:03+02:00
---

# Testing — End-to-End Scenarios

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

Verify the system works as a **whole**, not just per-service. E2E tests exercise the real flow: Flutter-style gRPC call → service → DB → Pub/Sub → worker → DB → next service. Catch the bugs unit tests can't see — wrong proto field names, broken auth propagation, schema drift, deprecated APIs, IAM misconfigs, race conditions in pipelines.

## Test pyramid in this repo

| Layer | What it covers | Where |
|---|---|---|
| **Unit** | Pure functions, parsers, single component | `*_test.go` colocated with code |
| **Integration** | One service against real DB / KMS / GCS via mocks or testcontainers | `internal/.../` `*_test.go` (limited today) |
| **E2E (smoke)** | Multiple services in staging GCP project | `tests/e2e/*.sh` |
| **E2E (full pipeline)** | Audio upload → transcript → report end-to-end | **NOT YET** — to be built |
| **Manual UI** | Flutter app against staging | iOS simulator + therapist test account |

## Status (2026-07-06)

- **Go unit tests** exist for: `pkg/cryptobox`, `pkg/transcription/chunker`, `pkg/i18n/speakerlabels`, `cmd/stt-worker` (parser), `identity-svc/internal/adapters/grpc` (server).
- **Flutter unit tests — 250 tests across 27 files** (updated 2026-07-06). Run via `flutter test --reporter compact` from `flutter-app/superwizor/`. Coverage by module:
  - `test/cache/dto/` — JSON round-trip with field-count guards for every DTO (PatientDto, SessionDto, TranscriptDto, ReportDto, SessionDetailsDto)
  - `test/cache/cache_box_test.dart` — TTL gates, schema-version drop, corrupt entry self-heal, LRU index
  - `test/cache/cache_manager_test.dart` — open/close lifecycle, LRU eviction across boxes, evictPatient cascade, therapist switch
  - `test/cache/eviction_cascade_test.dart` — full delete-patient cascade through PatientRepository
  - `test/repositories/` — miss/hit/stale/invalidate per repo, per-therapist scoping
  - `test/uploads/pending_upload_test.dart` — JSON round-trip + state machine invariants
  - `test/uploads/upload_queue_test.dart` — dueNow ordering, pruneStale (7-day max age), corrupt-row skip
  - `test/uploads/upload_worker_test.dart` — every phase transition + every error classifier branch
  - `test/uploads/upload_queue_runner_test.dart` — connectivity restore, snapshot stream, retryFailed/dismiss
  - `test/uploads/upload_state_transitions_test.dart` — end-to-end happy/sad paths through the runner + worker + Firestore-status callbacks
  - `test/uploads/upload_error_test.dart` — error classification exhaustive tests
  - `test/uploads/upload_io_resumable_test.dart` — resumable upload chunking
  - `test/services/recording_service_test.dart` — OS interruption, reconcileWithNative, pause/resume probe, hadInterruption latch, zombie timer detection
  - `test/services/live_activity_service_test.dart` — MethodChannel bridge: start/update/stop/reportReady, status enum serialization, error swallowing
  - `test/services/recording_foreground_service_test.dart` — Android FGS MethodChannel calls
  - `test/services/recording_manifest_store_test.dart` — manifest persistence for recovery
  - `test/services/recording_recovery_service_test.dart` — orphaned recording detection + re-enqueue
  - `test/services/secure_audio_storage_isolate_test.dart` — AES-GCM encrypt→decrypt through background isolate
  - `test/mapping/` — DTO mapping between proto and domain models
  - `test/providers/` — Riverpod provider logic (avatar, sort/filter)
  - `test/utils/action_plan_extractor_test.dart` — report action plan parsing
  - `test/audio_converter_service_test.dart` — FLAC encoding pipeline
  - `test/components_test.dart` — base component rendering
- **Flutter widget tests — gap.** No widget tests exist today. High-complexity screens (RecordingScreen, PatientDetailsScreen) have deep provider dependency trees that make widget-test setup expensive. Feature-flag screens and simple form screens are candidates for first widget tests.
- **Phase 1 smoke** works: `tests/e2e/test_create_patient_file.sh`, `tests/e2e/get_test_user.sh`.
- **Phase 2 E2E (audio + AI pipeline) — gap.** Verify via Flutter app manually.

## Flutter test standards

### Cardinal rule: regression tests must BREAK on the old code

When writing a test for a bug fix, it **must fail** if the fix is reverted. Tests that pass on both old and new code are noise, not coverage. Before committing a regression test, mentally (or literally) revert the fix and confirm the test would fail.

**Anti-pattern:**
```dart
// ❌ BAD: this passes on both old and new code
test('cancel transitions to idle', () async {
  await service.cancel();
  expect(service.state, RecordingState.idle); // always true
});
```

**Correct pattern:**
```dart
// ✅ GOOD: this ONLY passes after adding isRecording() check
test('reconcile detects dead recorder → error', () async {
  await service.start('s1');
  recorder.nativePaused = false;
  recorder.stopCalls = 1; // force isRecording() → false
  await service.reconcileWithNative();
  expect(service.state, RecordingState.error);
  // Old code: would stay recording (only checked isPaused)
});
```

### Regression test comment format

Every regression test must have a block comment explaining **what bug would return** if the fix is reverted:

```dart
// ── Regression: <short bug name> ──
// Bug: <what was wrong in the old code>
// Fix: <what the fix changed>
// Without fix: <what this test would show>
test('descriptive name → expected behavior', () async { ... });
```

### Mocking patterns (use what's established)

| What you're testing | Mock strategy | Example file |
|---|---|---|
| `RecordingService` (native recorder) | `_FakeRecorder extends Fake implements AudioRecorder` | `recording_service_test.dart` |
| `LiveActivityService` (MethodChannel) | `setMockMethodCallHandler` on `MethodChannel` | `live_activity_service_test.dart` |
| `RecordingForegroundService` (MethodChannel) | Same + `debugOverrideSupported = true` | `recording_foreground_service_test.dart` |
| `UploadWorker` (network I/O) | `FakeUploadIo implements UploadIo` | `upload_worker_test.dart` |
| `CacheBox` / repos (Hive) | Real Hive with `Directory.systemTemp` | `cache_box_test.dart` |
| `SecureAudioStorage` (AES-GCM isolate) | Real crypto with temp dir | `secure_audio_storage_isolate_test.dart` |

**Key conventions:**
- **Fake > Mock.** Use `extends Fake implements X` (from `flutter_test`), not `mockito`. Fakes are explicit, compile-checked, and don't need codegen.
- **`pump()` helper.** Most async test files define `Future<void> pump([int ms = 20]) => Future.delayed(...)` for stream propagation. Use it instead of raw delays.
- **Temp dirs.** Use `Directory.systemTemp.createTemp('prefix_')` in `setUp()`, delete in `tearDown()`. Never use hardcoded paths.
- **Fire-and-forget services** (LiveActivity, FGS): test that MethodChannel calls arrive with correct method + arguments. Don't test native behavior (that's Swift/Kotlin territory).

### Adding tests to existing files

When fixing a bug in `FooService`:
1. Open `test/services/foo_service_test.dart`.
2. Add your test **at the end of `main()`**, after the last existing test.
3. Group regression tests with a comment header: `// ── Regression: <ticket/bug> ──`.
4. If the `_Fake*` class needs a new method override, add it to the fake — don't create a new fake.
5. Run `flutter test test/services/foo_service_test.dart --reporter compact` to verify.
6. Run `flutter test --reporter compact` to verify no regressions across the full suite.

### What NOT to unit-test (and how to cover it instead)

Some fixes live in UI code (`ConsumerState` methods) that's impossible to unit-test without a full widget-test harness. Examples:
- `_confirmDiscardOnBack()` in `RecordingScreen` — requires mounted widget with 15+ providers.
- Navigation flows (push/pop) with `navigatorKey`.
- Dialog/sheet confirmations.

**For these, document them as manual test scenarios:**
```
Manual regression check:
1. Start recording → tap ← (back arrow) → "Skasuj bezpowrotnie" → confirm
2. Assert: widget/Live Activity disappears immediately
3. Assert: no orphaned session in patient file list
```

Until widget-test infrastructure exists, this is the honest coverage strategy.

## Repo paths

```
tests/                                    ← shell-based E2E tests
└── e2e/
    ├── get_test_user.sh                  ← create test Firebase user + DB row
    └── test_create_patient_file.sh       ← Phase 1 happy path

superwizor-backend/tests/e2e/             ← duplicates above (legacy)

superwizor-backend/pkg/<pkg>/*_test.go    ← Go unit tests
superwizor-backend/services/<svc>/internal/.../*_test.go  ← Go unit tests

flutter-app/superwizor/test/              ← Flutter unit tests (250, updated 2026-07-06)
├── cache/                                ← DTOs, box, manager, eviction cascade
├── mapping/                              ← proto ↔ domain DTO mapping
├── providers/                            ← Riverpod provider logic
├── repositories/                         ← patient / session / session-details repos
├── services/                             ← recording, live activity, FGS, recovery, crypto
├── uploads/                              ← queue, worker, runner, transitions, errors
├── utils/                                ← action plan extractor
├── audio_converter_service_test.dart     ← FLAC pipeline
└── components_test.dart                  ← base component rendering

superwizor-backend/Makefile               ← `make test` runs `go test ./...` per module
.github/workflows/ci.yml                  ← CI runs `make test` on every push
```

## Tooling

| Tool | Purpose |
|---|---|
| `grpcurl` | gRPC reflection-based CLI client (TLS to Cloud Run) |
| `gcloud` | Auth (`print-identity-token`), service discovery, secrets, Pub/Sub |
| `cloud-sql-proxy` | Direct DB access for assertions (correct arch binary required) |
| `psql` / `pg_isready` | DB queries for assertions |
| `gsutil` / `gcloud storage` | GCS object upload (signed URL alt path) |
| Go `testing` + `stretchr/testify` | Unit + integration tests |
| `pgxpool` (mock-friendly) | DB layer in tests |
| `pkg/cryptobox.NewMockBox()` | Encryption stub — returns plaintext as ciphertext for round-trip tests |
| `gen/go/<svc>/v1/*.pb.go` | Generated stubs — usable as test clients in Go |

## Test data conventions

- **Test users:** `firebase_uid: "test_uid_<timestamp>"`, `email: "test_<timestamp>@example.com"`. Get away with mass-creation by suffix; clean up via soft delete (`UpdateUser` with `is_deleted=true`) — never hard delete.
- **Test patient files:** `working_alias: "E2E Test ..."`. Filter `WHERE working_alias LIKE 'E2E Test %'` to clean.
- **Test sessions:** mark with `therapist_observations LIKE 'E2E TEST RUN <run_id>%'` so cleanup is mechanical.
- **Test audio:** [`test-audio.wav`](../../test-audio.wav) at repo root (existing). Convert to `m4a` via `ffmpeg` for upload tests; ≤300 MB, mono, 16kHz preferred (matches Chirp 3 expectations).
- **Project:** all tests run against staging `superwizor-ai-25ecd`. **There is no separate test project.** Plan accordingly: never seed PII; use clearly-fake data.

## Auth in E2E tests

Two paths depending on what's being tested:

1. **Service-to-service IAM token** (the existing pattern):
   ```bash
   TOKEN=$(gcloud auth print-identity-token)
   ```
   Works for `allUsers`-bound services that don't strictly require Firebase ID tokens. Limitation: doesn't exercise the Firebase token validation code path.

2. **Real Firebase ID token** (the path Flutter uses):
   ```bash
   # Mint a custom token via Firebase Admin SDK, then exchange for ID token
   FIREBASE_API_KEY="<from firebase_options.dart>"
   CUSTOM_TOKEN=$(node ../scripts/mint_custom_token.js <test_uid>)
   ID_TOKEN=$(curl -s "https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$FIREBASE_API_KEY" \
     -d "{\"token\":\"$CUSTOM_TOKEN\",\"returnSecureToken\":true}" \
     | jq -r .idToken)
   ```
   Required for tests that rely on `users.firebase_uid` lookup or claim-specific validation.

## E2E scenarios to cover (priority-ordered)

### Tier 1 — happy paths (must always pass)

#### 1. Identity: register + login + get user
```
RegisterUser(firebase_uid, email, role=THERAPIST) → User row created in DB
ValidateToken(firebase_id_token) → UserContext{user_id, org_id, role}
GetUser(user_id) → expected User
```
Asserts: `users` row exists; `firebase_uid` matches; `deleted_at IS NULL`.

#### 2. Clinical: create patient file → list → get details
```
CreatePatientFile(therapist_id, modality_code=CBT, working_alias) → PatientFile
ListPatientFiles(therapist_id) → contains the new file
GetPatientFileDetails(file_id) → full record incl. modality
```
Asserts: `patient_files` row, `therapist_patient_relations` link.

#### 3. Sessions: create session → list
```
CreateSession(patient_file_id, session_date, session_number=1) → Session{status=CREATED}
ListSessions(therapist_id) → contains it
```
Asserts: `sessions.status='CREATED'`, `speaker_label_mapping='{}'::jsonb`.

#### 4. Ingestion: request signed URL → upload audio → confirm
```
billing-svc.CheckQuota(usage_type=session_analysis) → allowed=true (Phase 2 stub)
RequestUploadTicket(session_id, idempotency_key) → UploadTicket{signed_url, upload_id}
PUT signed_url < test_audio.m4a (Content-Type: audio/m4a)
ConfirmUpload(upload_id) → audio_uploads.status=UPLOADED, audio.uploaded published
```
Asserts: `audio_uploads` row state machine, GCS object exists, Pub/Sub message in subscription.

#### 5. AI pipeline: STT happy path (slowest test)
```
(continues from #4) → wait for stt-worker (Pub/Sub triggered, ~30-90s)
Poll sessions.status until ANALYZING
Assert: transcripts row exists, transcript_ciphertext is non-empty,
        transcript_segments rows exist (chunk_idx ordering preserved),
        sessions.language_code='pl-PL'
Assert: audio object DELETED from GCS (or expires within 48h via OLM)
Assert: transcript.completed published
```

#### 6. AI pipeline: LLM happy path
```
(continues from #5) → wait for llm-worker (~30-180s; Vertex AI cold start)
Poll sessions.status until COMPLETED
Assert: therapist_reports row exists, report_ciphertext non-empty
Assert: hitop_measurements rows exist (with valid dimension_code enum values)
Assert: sessions.speaker_label_mapping populated (e.g. {"1":"Osoba 1","2":"Osoba 2"})
Assert: transcript_segments[*].speaker_tag and speaker_label updated
Assert: report.generated published
```

#### 7. Speaker labels: rebuild canonical blob
```
UpdateSpeakerLabels(session_id, mapping={"1":"Therapist","2":"Patient John"})
Assert: sessions.speaker_label_mapping updated
Assert: transcript_segments[*].speaker_label updated for matching tags
Assert: transcripts.transcript_ciphertext changed (decrypt → verify new labels in blob lines)
```
Crucial because of ADR-IMPL-006 (canonical blob).

### Tier 2 — important contracts (should pass)

#### 8. Idempotency: same key returns same result
```
RegisterUser({firebase_uid, ..., idempotency_key=K}) → User{id=A}
RegisterUser({firebase_uid, ..., idempotency_key=K}) → User{id=A}  # NOT a new row
RegisterUser({firebase_uid, different email, idempotency_key=K}) → AlreadyExists / 409
```

```
RequestUploadTicket(session_id, idempotency_key=K) → ticket1
RequestUploadTicket(session_id, idempotency_key=K) → ticket1  # same upload_id
```

#### 9. Auth: Firebase token propagation
```
With valid Firebase token: clinical-svc.ListPatientFiles → 200 OK
With expired Firebase token: → 401 (app layer)
With no token: → 401 (Cloud Run frontend) [for `allUsers`-bound services this is app-layer rejection]
With another tenant's token (different therapist_id): → empty list (RBAC)
```

#### 10. Quota gate (Phase 2 stub behavior)
```
billing-svc.CheckQuota(any input) → allowed=true (today)
ingestion-svc.RequestUploadTicket → succeeds even at hypothetical limit
# Phase 3 will add: rejection at limit, increment on confirm.
```

#### 11. Soft delete: user / patient file
```
DeletePatientFile(file_id) → patient_files.deleted_at = now()
ListPatientFiles(therapist_id) → does NOT contain the file
GetPatientFileDetails(file_id) → NotFound (or returns flagged with deleted_at, depending on contract)
DB query: SELECT * FROM patient_files WHERE id=$1 → row exists (audit trail preserved)
```

#### 12. Encryption round-trip
```
Decrypt(transcripts.transcript_ciphertext, transcript_encrypted_dek) → valid blob JSON
Decrypt(therapist_reports.report_ciphertext, report_encrypted_dek) → valid ReportPayload
Try to decrypt with wrong DEK → AuthenticationFailed
```

### Tier 3 — failure paths (should also pass; tests resilience)

#### 13. Pub/Sub DLQ on poison message
```
Publish a malformed audio.uploaded payload (missing object_path)
After 6 delivery attempts (per terraform retry policy):
  Assert: stt-worker doesn't crash
  Assert: message lands in audio.uploaded.dlq subscription
```

#### 14. Worker idempotency on redelivery
```
Force Pub/Sub to redeliver the same audio.uploaded message twice (e.g., kill ack)
Assert: only one transcripts row created (FOR UPDATE SKIP LOCKED prevented double-work)
Assert: audio object deleted exactly once (or zero — never twice)
```

#### 15. STT failure → session error path
```
Upload corrupt/empty audio (zero bytes)
Wait for stt-worker
Assert: sessions.status = ERRORED (or whatever the error enum is in your schema)
Assert: sessions.error_message populated
Assert: transcript.completed NOT published
```

#### 16. LLM JSON schema violation (rare but real)
```
Mock Gemini to return schema-invalid JSON (or hit a real edge case via short audio)
Assert: llm-worker logs validation error
Assert: sessions.status = ERRORED
Assert: report.generated NOT published
Assert: message goes to transcript.completed.dlq after retries
```

#### 17. Migration drift detection
```
Run all migrations on a clean DB
Compare schema dump to a checked-in baseline (per-domain)
Fail if any drift (column added/removed/renamed without paired migration)
```

### Tier 4 — performance benchmarks (informational)

Track over time, alert on regressions:
- **STT latency**: time from `audio.uploaded` ack to `transcript.completed` ack — typical 10-60s for 5-min audio.
- **LLM latency**: `transcript.completed` ack to `report.generated` ack — typical 20-90s.
- **End-to-end**: signed URL request → report visible in `clinical-svc.GetReport` — typical 60-180s.
- **Cold start**: first invocation after >5min idle (worker `min_instance_count=0`).
- **gRPC p95**: identity/clinical/ingestion read calls, target <200ms.

## How to write a new E2E test

### Shell-based (current pattern)

1. Copy `tests/e2e/test_create_patient_file.sh` as a template.
2. Fetch service URLs via `gcloud run services describe`.
3. Get a token (`print-identity-token` for service-style; Firebase ID token for client-style — see "Auth" above).
4. Use `grpcurl` with `:443` and `-H "authorization: Bearer $TOKEN"`.
5. Capture IDs from JSON output via `grep` / `jq`.
6. Assert via grep/jq + exit codes; print clear error messages on failure.
7. Add cleanup at the end (or rely on soft delete + nightly purge).

### Go-based (recommended for Tier 1+2)

Sketch:
```go
func TestE2E_FullPipeline(t *testing.T) {
    ctx := context.Background()
    cfg := loadStagingConfig(t)  // URLs, project, test creds

    identityClient := identityv1.NewIdentityServiceClient(dialTLS(t, cfg.IdentityURL))
    clinicalClient := clinicalv1.NewClinicalServiceClient(dialTLS(t, cfg.ClinicalURL))
    ingestionClient := ingestionv1.NewIngestionServiceClient(dialTLS(t, cfg.IngestionURL))

    // 1. Create therapist
    user := mustRegister(t, identityClient, "test_uid_"+uniqSuffix())

    // 2. Create patient file
    pf := mustCreatePatientFile(t, clinicalClient, user.Id, "CBT")

    // 3. Create session
    session := mustCreateSession(t, clinicalClient, pf.Id, time.Now())

    // 4. Request signed URL
    ticket := mustRequestUploadTicket(t, ingestionClient, session.Id)

    // 5. Upload audio
    mustPutSignedURL(t, ticket.SignedUrl, "testdata/short.m4a")

    // 6. Confirm
    mustConfirmUpload(t, ingestionClient, ticket.UploadId)

    // 7. Wait for STT (poll session status)
    waitForStatus(t, clinicalClient, session.Id, "ANALYZING", 120*time.Second)

    // 8. Wait for LLM (poll session status)
    waitForStatus(t, clinicalClient, session.Id, "COMPLETED", 240*time.Second)

    // 9. Read report
    report := mustGetReport(t, clinicalClient, session.Id)

    // 10. Assertions
    assert.NotEmpty(t, report.Title)
    assert.NotEmpty(t, report.SummaryShort)
    assert.GreaterOrEqual(t, len(report.MainThemes), 1)
    assert.GreaterOrEqual(t, len(report.HitopDimensions), 1)

    // 11. Cleanup (soft delete)
    mustSoftDeletePatientFile(t, clinicalClient, pf.Id)
}
```

Build tag `// +build e2e` so it doesn't run in `make test` but does run in a dedicated CI job. Run with `go test -tags=e2e ./tests/...`.

### Pyramid placement

| Test | Layer | Run frequency |
|---|---|---|
| Tier 1 happy paths | E2E in CI | Every push to main |
| Tier 2 contracts | E2E in CI | Every push to main |
| Tier 3 failure paths | E2E nightly | Cron-triggered |
| Tier 4 perf | E2E weekly | Cron + dashboard |
| Unit | `make test` | Every push (already wired) |

## Constraining ADRs

| ADR | What it forces in tests |
|---|---|
| **P1 (Zero Data Loss)** | Tests must verify idempotency. Send each Pub/Sub message twice and assert single-effect. |
| **P3 (EU residency)** | Test infrastructure runs from `europe-central2` runners (or local in EU); don't ship test data through US Cloud Run instances. |
| **P4 (Flutter read-only on AI reports)** | Negative test: try to call any hypothetical write-report endpoint with a Firebase token; must fail with `Unimplemented` or `PermissionDenied`. |
| **ADR-IMPL-002** | After speaker label edit, blob must contain the NEW labels — decrypt and verify text. |
| **ADR-IMPL-006** | After speaker label edit, the canonical blob must change. Test by hashing ciphertext before/after. |
| **ADR-IMPL-007** | Polish-language test fixtures only (`pl-PL` audio); the diarization path is LLM-based and tuned for Polish. English-language tests are misleading. |

## Common gotchas

- **Don't run E2E from a developer laptop against a fresh staging deploy without warming workers.** Cloud Functions cold start = ~10-15s extra latency. Either set `min_instance_count=1` for the test run, or budget more wait time.
- **`gcloud auth print-identity-token`** mints a Google-IAM token, NOT a Firebase token. For services that strictly validate Firebase claims (audience = Firebase project ID), this won't work — mint a real Firebase ID token instead.
- **Firebase Admin SDK with ADC needs `signBlob` IAM grant.** When using `gcloud auth application-default login` (no JSON key), `auth().CustomToken()` falls back to calling IAM `signBlob` on `firebase-adminsdk-fbsvc@<project>`. The calling principal needs `roles/iam.serviceAccountTokenCreator` on that SA. Managed in `infra/environments/staging/service-accounts.tf` via `var.e2e_token_minters`. Quick fix without terraform: `gcloud iam service-accounts add-iam-policy-binding firebase-adminsdk-fbsvc@${PROJECT}.iam.gserviceaccount.com --member="user:$(gcloud config get-value account)" --role="roles/iam.serviceAccountTokenCreator"`.
- **Pub/Sub message inspection** without ACK'ing it: use `gcloud pubsub subscriptions pull <sub> --auto-ack=false --limit=10`. ACKing during a test creates state drift.
- **Test data accumulation:** staging DB will fill up if every test run leaves a soft-deleted user. Add a nightly cleanup Cloud Run Job that hard-deletes rows where `deleted_at < now() - INTERVAL '7 days' AND email LIKE 'test_%@example.com'`.
- **Race in #6 (LLM happy path):** if you poll too fast and the worker hasn't started, you'll read the old status. Always sleep ~5s after upload before first poll.
- **Vertex AI quotas:** Gemini 2.5 PRO has rate limits per project. A flaky perf test that retries 50x can blow your day's quota. Cap retries at 3.
- **`speaker_label_mapping` JSON keys are STRINGS** (e.g., `"1"` not `1`). Test fixtures in Go must use `map[string]string`, not `map[int32]string`.
- **CMEK key rotation** can transiently fail decryption tests. The KMS module has 90-day rotation; test infra should not assume a specific key version.

## Source-doc pointers

- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §11 (Observability) — what to alert on.
- `docs/05_FAZA_1_TOZSAMOSC_DANE.md` lines 3376–3676 — Phase 1 smoke test scripts and observability spec.
- `docs/06_FAZA_2_INGESTION_AI.md` Sprint 2.2 §"Smoke test" (lines 1466–1485), Sprint 2.5 §"Smoke test" — Phase 2 smoke patterns.
- `tests/e2e/*.sh` — actual scripts in repo today.
