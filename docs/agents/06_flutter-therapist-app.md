# Flutter Therapist App

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

Mobile (iOS/Android) and web app for therapists. Records sessions, lists patients/sessions, displays AI-generated reports. **Read-only on AI reports** (P4 + P5 in architecture).

## Status (2026-05-07)

- Phase 1 — login + patient files list working against staging.
- Phase 2 — audio recording → upload via signed URL → poll/subscribe for report → display report being iterated.
- Web build hits gRPC-Web limitations (see "Web vs native" below).

## Repo paths

```
flutter-app/superwizor/
├── lib/
│   ├── main.dart                     # entry point
│   ├── firebase_options.dart         # FlutterFire config
│   ├── constants/
│   ├── generated/                    # proto stubs (clinical, identity, ingestion)
│   ├── models/
│   ├── providers/
│   │   ├── grpc_provider.dart        # GrpcClients riverpod provider
│   │   └── ...
│   ├── screens/
│   │   ├── login_screen.dart
│   │   └── ...
│   ├── services/
│   │   └── grpc_client.dart          # GrpcClients class + AuthInterceptor
│   ├── theme/
│   └── widgets/
├── ios/, android/, web/, macos/, ...
└── pubspec.yaml
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

## iPhone M4A upload flow (added 2026-05-20)

iPhone Voice Memos / WhatsApp voice notes / iOS share-sheet exports
all land as AAC-in-MP4. Chirp 3 rejects this codec. Two-layer fix:

1. **Client-side (iOS native)** — `ios/Runner/AudioConverter.swift`
   uses `AVAudioFile` + `AVAudioConverter` + AudioToolbox's FLAC
   writer (`kAudioFormatFLAC`) to transcode on-device. 5-10x
   realtime on iPhone 15. Exposes a `MethodChannel` named
   `ai.superwizor/audio_converter` plus a sibling
   `EventChannel` for progress. Dart wrapper lives at
   `lib/services/audio_converter_service.dart::convertM4aToFlac`.

2. **Server-side fallback** — on Android/web/iOS-decode-failure,
   the client uploads the original M4A then calls
   `ingestion.ConvertAudio(audio_upload_id)`. Server transcodes via
   ffmpeg in the ingestion-svc Cloud Run image. See
   `docs/agents/04_ingestion-svc.md#ConvertAudio`.

The wiring in `lib/screens/new_session_screen.dart::_convertAndUploadFile`
adds an `ext == '.m4a' || ext == '.mp4' || ext == '.aac'` branch with
a try/catch that flips `needsServerSideConversion=true` on iOS
decode failure or non-iOS platforms.

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

## Common gotchas

- **`Unsupported operation: not supported by gRPC-web`** — using `.grpc(...)` factory on web. Switch to `.toSingleEndpoint(...)`.
- **HTML 401 page on first call** — Cloud Run IAM rejecting before app sees the request. Fix on the GCP side, not in Dart.
- **Firebase ID token: `audience` mismatch** — Firebase project ID in `firebase_options.dart` doesn't match what backend expects. Both sides must reference `superwizor-ai-25ecd`.
- **`flutter pub get` fails after proto changes** — make sure `lib/generated/` is up to date; run `protoc` (Flutter doesn't do this automatically).
- **Web build doesn't connect to backend** — backend is not yet `grpcweb.WrapServer`-wrapped. Use iOS simulator for now, or add the wrapper to identity/clinical/ingestion main.go.

## Source-doc pointers

- `docs/05_FAZA_1_TOZSAMOSC_DANE.md` Sprint 1.4 (lines 2976–3375) — Flutter project init, Firebase setup, generated proto stubs, minimal app: login + patient files list, smoke test.
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §6 (Firestore as sync layer, lines 631–724).
