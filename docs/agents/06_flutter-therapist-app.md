---
type: Agent Context
title: "Flutter Therapist App"
description: "Mobile (iOS/Android) and web app for therapists. Records sessions, lists patients/sessions, displays AI-generated reports. Read-only on AI reports (P4 + P5 i..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/agents/06_flutter-therapist-app.md
tags: [agents]
timestamp: 2026-05-25T18:11:17+02:00
---

# Flutter Therapist App

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

Mobile (iOS/Android) and web app for therapists. Records sessions, lists patients/sessions, displays AI-generated reports. **Read-only on AI reports** (P4 + P5 in architecture).

## Status (2026-05-21)

- Phase 1 — login + patient files list working against staging.
- Phase 2 — audio recording → upload via signed URL → poll/subscribe for report → display report being iterated.
- Web build hits gRPC-Web limitations (see "Web vs native" below).
- **Local cache + offline upload queue shipped** (2026-05-21) — see new section below. Patients/sessions/transcripts/reports now cached client-side; both file-upload and live-recording paths flow through a durable Hive queue that survives app kill and resumes on connectivity restore.

## Repo paths

```
flutter-app/superwizor/
├── lib/
│   ├── main.dart                     # entry point + UploadQueueLifecycleObserver
│   ├── firebase_options.dart         # FlutterFire config
│   ├── constants/
│   ├── generated/                    # proto stubs (clinical, identity, ingestion, notification)
│   ├── models/                       # UI-facing Patient/Session
│   ├── cache/                        # encrypted Hive cache + DTOs (added 2026-05-21)
│   │   ├── cache_keys.dart           # therapist-scoped box names
│   │   ├── cache_cipher.dart         # per-therapist AES-256 via flutter_secure_storage
│   │   ├── cache_envelope.dart       # TTL + LRU metadata wrapper
│   │   ├── cache_box.dart            # generic CacheBox<T>
│   │   ├── cache_manager.dart        # 300 MB cross-box LRU + evictPatient cascade
│   │   ├── cache_provider.dart       # Riverpod gateway (opens boxes on sign-in)
│   │   └── dto/                      # PatientDto, SessionDto, TranscriptDto, ReportDto, SessionDetailsDto
│   ├── repositories/                 # stale-while-revalidate over cache + gRPC (added 2026-05-21)
│   │   ├── patient_repository.dart
│   │   ├── session_repository.dart
│   │   └── session_details_repository.dart
│   ├── uploads/                      # durable offline upload queue (added 2026-05-21)
│   │   ├── pending_upload.dart       # DTO + phase state machine
│   │   ├── upload_queue.dart         # Hive-backed durable store + 7d age sweep
│   │   ├── upload_worker.dart        # phase advance + 3-bucket error classifier
│   │   ├── upload_error.dart         # retryable / signedUrlExpired / terminal classifier
│   │   ├── upload_io.dart            # injectable side-effect surface
│   │   ├── upload_io_grpc.dart       # production gRPC + HTTP impl
│   │   ├── upload_queue_runner.dart  # tick loop + connectivity + Firestore-status subs
│   │   └── upload_queue_provider.dart # Riverpod gateway + lifecycle observer
│   ├── providers/
│   │   ├── grpc_provider.dart        # GrpcClients riverpod provider
│   │   ├── current_user_provider.dart # Firebase UID → users.id (UUID)
│   │   ├── patient_provider.dart     # PatientsNotifier / SessionsNotifier (cache-aware)
│   │   ├── session_details_provider.dart # returns SessionDetailsDto via repo
│   │   └── services_provider.dart
│   ├── screens/
│   │   ├── login_screen.dart
│   │   ├── home_screen.dart          # hosts PendingUploadsPill in header
│   │   ├── pending_uploads_screen.dart # list view with retry/dismiss
│   │   ├── session_status_screen.dart # accepts sessionId OR queue localId
│   │   └── ...
│   ├── services/
│   │   ├── grpc_client.dart          # GrpcClients class + AuthInterceptor
│   │   ├── secure_audio_storage_service.dart # AES-256-GCM chunk store
│   │   └── session_state_listener.dart # Firestore session_states stream
│   ├── theme/
│   └── widgets/
│       └── pending_uploads_pill.dart # home-header status chip
├── ios/, android/, web/, macos/, ...
└── pubspec.yaml                       # connectivity_plus added 2026-05-21
```

## gRPC client setup

`lib/services/grpc_client.dart` has the canonical setup. Three channels:

```dart
identityChannel = GrpcOrGrpcWebClientChannel.toSingleEndpoint(
  host: 'identity-svc-...run.app',
  port: 443,
  transportSecure: true,
);
// same for clinicalChannel, ingestionChannel
```

> **CRITICAL:** Use `.toSingleEndpoint(...)` — the cross-platform factory. On native it picks HTTP/2 gRPC; on web it picks gRPC-Web. The older `.grpc(...)` factory throws `UnsupportedOperation: not supported by gRPC-web` on web. We hit this and fixed it.

`AuthInterceptor` (also in `grpc_client.dart`) attaches the Firebase ID token to every call:
```dart
options.mergedWith(CallOptions(
  providers: [_authProvider],
  timeout: const Duration(seconds: 30),
));
```
The `_authProvider` reads `fb_auth.FirebaseAuth.instance.currentUser?.getIdToken()`.

## State / DI

Riverpod (`flutter_riverpod`). Top-level `grpcClientsProvider` injects the `GrpcClients` singleton. Screens access it via `ref.read(grpcClientsProvider)`.

```dart
final grpcClientsProvider = Provider<GrpcClients>((ref) { ... });
```

## Auth flow

1. User signs in via FlutterFire (Firebase Auth UI or custom screen).
2. Firebase issues an ID token (audience = Firebase project ID = `superwizor-ai-25ecd`).
3. App calls `identity-svc.RegisterUser` (first time) or `GetUser` (subsequent), passing the ID token.
4. Token attached automatically to every gRPC call by `AuthInterceptor`.
5. Token expires after 1 hour; FirebaseAuth auto-refreshes — `getIdToken()` returns the fresh one.

## Web vs native

| Aspect | Native (iOS / Android / macOS) | Web |
|---|---|---|
| Transport | Native gRPC (HTTP/2) | gRPC-Web (HTTP/1.1 with base64 framing) |
| Backend support | Cloud Run with `--use-http2` works directly | **Server must wrap gRPC server in `grpcweb.WrapServer(...)` (improbable-eng/grpc-web). Currently NOT done — web calls will fail.** |
| Firebase Auth | works | works |
| Recording (`flutter_sound` etc.) | full support | limited (browser MediaRecorder constraints) |

For day-to-day dev, use the **iOS simulator** to bypass gRPC-Web until backend is wrapped. The web build is needed for the (future) therapist registration portal.

> Source for the web error we hit and fixed: see commit history around `grpc_client.dart`.

## Permissions / IAM (the Cloud Run side)

The Flutter-facing services (`identity-svc`, `clinical-svc`, `ingestion-svc`) MUST be bound `allUsers → roles/run.invoker` so the Cloud Run frontend lets requests through. The app validates Firebase tokens at the application layer.

If you get a 401 HTML page (not a gRPC error), it's the Cloud Run IAM gate, not your code. Fix at infra:
```bash
gcloud run services add-iam-policy-binding <svc> \
  --region=europe-central2 --member=allUsers --role=roles/run.invoker
```

> **`allAuthenticatedUsers` is a footgun** — that means "any GCP-IAM-authenticated identity", NOT "any user authenticated by your app". Firebase tokens fail this check.

## Firestore (mobile sync)

Per ADR-006, Firestore is the **read-only mirror** of session status for the mobile client to subscribe to:
- Backend writes `session_state/{session_id}` documents (notification-svc — Phase 3).
- Flutter subscribes to that document for live status updates ("Transcribing...", "Analyzing...", "Done").
- Reports themselves are NEVER in Firestore — they're fetched via gRPC `clinical-svc.GetReport`.

Firestore rules enforce read-only for clients; backend writes via Admin SDK (notification-svc).

## Constraining ADRs

| ADR | What it forces |
|---|---|
| **P4** | NEVER add a UI flow that writes a report. Reports come from `clinical-svc.GetReport`. |
| **ADR-006** | Firestore is mirror-only; don't store domain truth there. |
| **ADR-005 (gRPC sync)** | All sync calls are gRPC, not REST. If a future endpoint is REST (e.g., the therapist registration form), it must be a separate, declared exception. |
| **ADR-IMPL-002** | Display speaker labels from `sessions.speaker_label_mapping` (e.g. "Osoba 1") OR allow therapist to rename them via `clinical-svc.UpdateSpeakerLabels`. Never hard-code "Therapist"/"Patient" in the UI. |

## iPhone M4A upload flow (updated 2026-05-25)

iPhone Voice Memos / WhatsApp voice notes / iOS share-sheet exports
all land as AAC-in-MP4. Chirp 3 rejects this codec. Two-layer fix:

1. **Client-side (iOS native)** — `ios/Runner/AudioConverter.swift`
   uses `AVAudioFile` + `AVAudioConverter` + AudioToolbox's FLAC
   writer (`kAudioFormatFLAC`) to transcode on-device. 5-10x
   realtime on iPhone 15. Exposes a `MethodChannel` named
   `ai.superwizor/audio_converter` plus a sibling
   `EventChannel` for progress. Dart wrapper lives at
   `lib/services/audio_converter_service.dart::convertM4aToFlac`.
   Battery and egress savings: 100 MB M4A → ~30 MB FLAC.

2. **Server-side fallback** — on Android/web/iOS-decode-failure,
   the client uploads the original M4A as-is. The server's in-process
   ingestion subscriber detects the non-Chirp-supported codec and
   runs ffmpeg to transcode in place on GCS before publishing
   `audio.uploaded`. No client-driven RPC; entirely async. See
   `docs/agents/04_ingestion-svc.md` (subscriber transcode-fallback
   path).

The wiring in `lib/screens/new_session_screen.dart::_convertAndUploadFile`
adds an `ext == '.m4a' || ext == '.mp4' || ext == '.aac'` branch with
a try/catch that flips `needsServerSideConversion=true` on iOS
decode failure or non-iOS platforms — the flag is informational
only (used for UI copy + queue analytics), since the upload phase
is the same regardless: PUT to GCS, done.

## Local cache (added 2026-05-21)

Encrypted Hive cache scoped per therapist. Three domain boxes
(`patients_v1__<uid>`, `sessions_v1__<uid>`, `session_details_v1__<uid>`)
backed by AES-256 keys held in `flutter_secure_storage`. Per-therapist
box-name suffix is belt-and-suspenders to the per-user key — a stale
handle physically cannot see another therapist's data.

**Layers:**

```
UI screens / Riverpod notifiers
      ↓
PatientRepository / SessionRepository / SessionDetailsRepository
      ↓                                ↓
   CacheBox<T>                     PatientFetcher / SessionFetcher
   (TTL + LRU)                     (gRPC ClinicalServiceClient)
      ↓
CacheManager (300 MB cross-box LRU + evictPatient cascade)
      ↓
encrypted Hive boxes (lib/cache/)
```

**Read contract (stale-while-revalidate):**
- Cache hit fresh → return immediately, no network.
- Cache hit stale → return cached for fast UI; background refresh updates state when it lands.
- Cache miss → block on network, write through.

**TTLs (soft / hard):** patients 24h / 30d • sessions 1h / 30d •
session_details 1h / 30d. Hard expiry deletes the entry on read.
Corrupt or schema-mismatched entries are self-healed (dropped) so
DTO field drift never blows up `fromJson`.

**Per-therapist key & logout:** `CacheCipher.forgetKeyFor(therapistId)`
deletes the secure-storage key — Hive box files on disk become
permanently undecodable. `CacheManager.clearForUser` then deletes the
box files; the key-delete is the second wall. Call both on hard
sign-out.

**Cascade-evict on patient delete:** `PatientRepository.evictPatient`
delegates to `CacheManager.evictPatient` which drops the patient row,
their session list, and every cached session_details where
`session.patientFileId` matches. Wired into `PatientsNotifier.deletePatientUser`
before the refresh fires.

**`TranscriptCacheStore` retired** — the legacy per-screen
transcript cache was removed in favour of `SessionDetailsRepository`,
which stores the whole `GetSessionDetails` composite and integrates
with the cross-box LRU.

## Offline upload queue (added 2026-05-21, simplified 2026-05-25)

Both upload paths — `lib/screens/new_session_screen.dart` (file
picker) and `lib/screens/recording_screen.dart` (live recording) —
now build a `PendingUpload` and `enqueueAndKick` the queue runner,
then navigate to `SessionStatusScreen(localId: ...)`. After Option
F (2026-05-25, feat/refactor-stt-architecture) the client-driven
pipeline shrank from five steps to **two**:

1. `CreateAudioUpload` — gRPC; returns `upload_id`, signed URL,
   and `session_id` (Option E).
2. HTTP PUT to GCS → terminal-success. Queue row flips to
   `phase=completed`, source cleanup runs, the runner removes the
   row once the server-side Firestore mirror confirms processing
   started.

The old `ConvertAudio` and `CompleteAudioUpload` calls are gone
entirely — ingestion-svc's in-process subscriber drives finalize
off the GCS bucket notification. Removed RPCs are not in the proto
anymore; clients calling them would get `codes.Unimplemented`.

**Durable state shape (`PendingUpload`):**
- `UploadSourceKind.encryptedChunks` — live recording. Chunks at
  `<docs>/sessions/<sessionId>/chunk_NNNNN.enc` (existing
  SecureAudioStorageService format). Worker decrypts to temp at PUT
  time, deletes temp in `finally`.
- `UploadSourceKind.plainFile` — file picker. Picked file is copied
  to `<docs>/queued_uploads/<localId>/<basename>` (stable across app
  kill — file_picker's OS cache path can be purged). Worker deletes
  the staging dir on terminal-success.

**Phase machine** (`UploadPhase`): `pending → created → completed`.
Legacy values `uploaded` / `converted` survive in the enum so old
Hive rows from pre-Option-F builds decode cleanly; the worker walks
any such row directly to `completed` on the first new tick
(`_doFinalize`) — the GCS PUT had already happened, the server's
subscriber will pick up the OBJECT_FINALIZE event independently.
Terminal: `completed`, `failed`. Runner advances rows to terminal
in one tick (within bounds of a scheduled backoff) so the
SessionStatusScreen stepper updates in real time rather than
waiting 60s between phases.

**Error classification** (`upload_error.dart`):
- **retryable** — gRPC UNAVAILABLE/DEADLINE_EXCEEDED/INTERNAL,
  network plumbing (Socket/Http/Timeout/ClientException), HTTP 5xx.
  Worker schedules exponential backoff with jitter
  (`min(60s × 2^n, 30min) ± 25%`).
- **signedUrlExpired** — HTTP 401/403/410 on PUT. Worker bounces row
  back to `pending` and clears uploadId/signedUrl; next tick re-runs
  CreateAudioUpload with the SAME `idempotencyKey` so the server
  returns the existing uploadId + a fresh URL (no duplicate
  audio_uploads row).
- **terminal** — gRPC FAILED_PRECONDITION (the MP3 codec gate shape),
  INVALID_ARGUMENT, NOT_FOUND, PERMISSION_DENIED, etc.; HTTP 4xx
  non-auth. Row marked `failed` with `terminatedAt`; user sees the
  worker's `lastError` in the failure sheet and the pill turns red.

Conservative default: unrecognised errors classify as **retryable**.
Worst case is wasted attempts on a permanent failure — the 7-day
max-age sweep eventually reaps it. The opposite mistake (silently
giving up on a transient blip) is a lost recording.

**Triggers** (runner picks up due rows on):
- `connectivity_plus.onConnectivityChanged` → kick the moment Wi-Fi
  or cellular returns.
- 60-second periodic timer while the runner is foregrounded.
- `AppLifecycleState.resumed` via `UploadQueueLifecycleObserver`
  installed in `main.dart`.
- Explicit `enqueueAndKick` from screens (synchronous; advances
  through phases in one tick).

**Kartoteka refresh on push events** — no polling. The runner
subscribes to Firestore `session_states/{sessionId}` (the doc that
notification-svc mirrors per Pub/Sub event) for every row whose
upload reached `phase=completed`. Two refresh callbacks fire to keep
the kartoteka in sync:

- `onUploadComplete(row)` — fires the instant the row hits
  `phase=completed`. The server has a real session in PROCESSING
  state; we `refresh()` both `PatientRepository` and
  `SessionRepository` so the new session appears in the kartoteka
  with "W trakcie analizy" instead of hiding behind a stale cached
  list.
- `onAnalysisComplete(row)` — fires when the Firestore subscription
  emits `status='done'` or `'failed'`. Refreshes the same
  repositories so the status flips to "Wgrane", then removes the
  row from the queue (pill on home disappears).

**Pending uploads UI** — `PendingUploadsPill` on the home header
(empty → hidden, has rows → "N w toku" / "N analiza" / "N błąd"
with distinct icons). Tap → `PendingUploadsScreen` list view with
per-row phase label, attempt count, error string, and retry / dismiss
buttons. Live-updates via `pendingUploadsStreamProvider`.

**SessionStatusScreen** accepts either:
- `sessionId` (legacy direct-result entry point), or
- `localId` (queue row ID) — watches the queue snapshot, surfaces
  phase-specific copy under the stepper ("Przesyłam plik na
  serwer...", "Plik na serwerze, finalizuję..."), then transparently
  switches to the sessionId-driven Firestore + clinical-svc
  listeners the moment the worker captures session_id from
  CreateAudioUploadResponse (Option E, Option F).

**Max queue age:** 7 days. `UploadQueue.pruneStale` force-terminates
older rows with sentinel `lastError='queue.max_age_exceeded'`. User
can dismiss the failed row from the list view.

## Recording → upload flow

We must switch the recording encoder to a format natively supported by chirp_3 (e.g., FLAC, WAV, or OPUS).

[MODIFY] 
recording_service.dart
Change encoder: AudioEncoder.aacLc to encoder: AudioEncoder.flac (or .wav / .opus).
```
User taps Record
  → flutter_sound captures audio AudioEncoder.flac (FLAC, 16kHz mono, ≤300MB)
  → on stop: ingestion-svc.RequestUploadTicket(idempotency_key)
  → receive signed URL
  → PUT audio to GCS (Content-Type: audio/flac, x-goog-content-length-range)
  → ingestion-svc.ConfirmUpload(upload_id) → emits to Pub/Sub
  → poll/subscribe for report via Firestore session_state OR
    clinical-svc.GetSessionDetails (status + transcript_id + report_id when ready)
  → display report
```

## Iteration guardrails

**Safe:**
- New screens, widgets, theme changes.
- New gRPC client methods over existing services (regen stubs from `proto/`).
- Riverpod refactors.
- New state subscriptions.

**Careful:**
- Authorization header injection — always go through `AuthInterceptor`, don't bypass to call services without a token.
- Firebase project ID — set in `firebase_options.dart`. Must match `superwizor-ai-25ecd` (audience claim) for backend validation to pass.
- `GrpcOrGrpcWebClientChannel.toSingleEndpoint` (not `.grpc`).
- Direct GCS PUT — use the signed URL exactly; don't try to authenticate with user credentials.

**Don't:**
- Bypass gRPC and call HTTP endpoints (services don't expose JSON).
- Cache the Firebase ID token statically — it expires hourly. Use `getIdToken()` each call.
- Read or write Firestore documents that aren't `session_state/{id}` — others have write-restricted rules.
- Embed long-lived secrets in the app bundle. There aren't any (Firebase config is fine to ship).
- **Run the ingestion pipeline inline from a screen.** All audio uploads go through `uploadQueueRunnerProvider.enqueueAndKick(...)` — keeps crash-safe durable state and gives the runner a chance to retry. The two-step pipeline (CreateAudioUpload → PUT) is exclusively the runner's job via `UploadIo`. Server-side finalize is **not** the client's job; do not re-add convert / complete RPCs.
- **Poll clinical-svc for session status.** notification-svc mirrors all status transitions to Firestore `session_states/{sessionId}`. Subscribe; do not poll. The 60s clinical-svc fallback in `SessionStatusScreen` is for statuses not yet mirrored to Firestore (`transcribing`, `failed` — ADR-IMPL-012 deferred); not a general escape hatch.
- **Generate a new `idempotencyKey` on retry.** The same key for the lifetime of a `PendingUpload` is what lets CreateAudioUpload return the original `upload_id` + a fresh signed URL when the previous URL expired. New key = duplicate audio_uploads row.
- **Add a fourth cache box without going through `CacheManager`.** Box names are therapist-scoped and the cipher is per-therapist; reach for `CacheManager.openForUser` semantics, don't open Hive boxes ad hoc.
- **Store DTOs as proto messages directly in Hive.** Generated proto classes are not designed for stable on-disk serialization (field-number renames, reserved-tag promotions silently shift bytes). Every cached entity gets a thin Dart DTO with explicit `toJson` / `fromJson` + `fromProto` adapter (lib/cache/dto/) — schema diffs surface at compile time.

## Common gotchas

- **`Unsupported operation: not supported by gRPC-web`** — using `.grpc(...)` factory on web. Switch to `.toSingleEndpoint(...)`.
- **HTML 401 page on first call** — Cloud Run IAM rejecting before app sees the request. Fix on the GCP side, not in Dart.
- **Firebase ID token: `audience` mismatch** — Firebase project ID in `firebase_options.dart` doesn't match what backend expects. Both sides must reference `superwizor-ai-25ecd`.
- **`flutter pub get` fails after proto changes** — make sure `lib/generated/` is up to date; run `protoc` (Flutter doesn't do this automatically).
- **Web build doesn't connect to backend** — backend is not yet `grpcweb.WrapServer`-wrapped. Use iOS simulator for now, or add the wrapper to identity/clinical/ingestion main.go.
- **Kartoteka shows session as "W trakcie analizy" forever** — the cache `onAnalysisComplete` callback isn't firing because the runner hasn't subscribed to `session_states/{sessionId}` for that row. Check `_sessionStatusStream` is wired in `upload_queue_provider.dart`. Confirm with `[upload-runner] subscribing to analysis status localId=...` debug log.
- **Upload pipeline stuck at "Przesyłam plik..." for 60s** — was a bug pre-2026-05-21 where the tick advanced only one phase per call. `_tick` now loops `runOne` until terminal or backoff. If a regression: check the inner `while (_running)` loop in `UploadQueueRunner._tick`.
- **New session missing from kartoteka during processing** — was a bug pre-2026-05-21 where the cache only refreshed on `onAnalysisComplete`. Both `onUploadComplete` (fires on `phase=completed`) AND `onAnalysisComplete` (fires on Firestore `done`/`failed`) now refresh `PatientRepository` + `SessionRepository`. If a regression: verify both callbacks fire by adding a debug log in `_refreshKartoteka`.
- **Pill never disappears after analysis finishes** — Firestore subscription not firing or `onAnalysisComplete` not running. Two causes: (1) notification-svc never wrote `session_states/{sessionId}` with `status='done'` (check the worker logs), (2) the runner's analysis subscription was created before the sessionId materialized (defensive: `_reconcileAnalysisSubscriptions` runs on every tick).
- **`HiveError: Box has already been closed`** during therapist switch — the previous runner's tick is mid-flight when the box closes. Benign; the new tick on the new box reseeds state.

## Source-doc pointers

- `docs/04_FAZA_1_TOZSAMOSC_DANE.md` Sprint 1.4 (lines 2976–3375) — Flutter project init, Firebase setup, generated proto stubs, minimal app: login + patient files list, smoke test.
- `docs/01_ARCHITEKTURA_TECHNICZNA.md` §6 (Firestore as sync layer, lines 631–724).
- `docs/08_FAZA_3_NOTIFICATIONS.md` — Firestore `session_states` doc shape, status transitions, FCM payload (the queue runner subscribes to the same doc).
- `docs/agents/10_notification-svc.md` — backend writer for `session_states`. Source of truth on which statuses are mirrored (`uploaded`, `analyzing`, `done`); `transcribing` + `failed` deferred per ADR-IMPL-012.
- `docs/12_ADDING_NEW_MODALITY.md` — how to add a new therapy modality end-to-end (backend seed migration + Flutter constants/widget/i18n wiring). Walks through `kModalities`, `ModalitySheet._modalityDisplayName`, and the ARB key pair.
