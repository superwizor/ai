---
description: Loads when editing the Flutter therapist app (Dart, gRPC clients, riverpod, Firebase Auth).
globs:
  - "flutter-app/**"
  - "**/*.dart"
  - "**/pubspec.yaml"
alwaysApply: false
---

# Flutter Therapist App

**Read [`docs/agents/06_flutter-therapist-app.md`](../../docs/agents/06_flutter-therapist-app.md) before editing.**

Quick orientation:

- **Mobile (iOS/Android) + web therapist client.** Records sessions, lists patients/sessions, displays AI reports. **Read-only on AI reports** (P4).

- **gRPC clients** in `lib/services/grpc_client.dart`. Three channels: `identityChannel`, `clinicalChannel`, `ingestionChannel`.

- **Use `GrpcOrGrpcWebClientChannel.toSingleEndpoint(...)`** — the cross-platform factory. On native it picks HTTP/2 gRPC; on web it picks gRPC-Web. The `.grpc(...)` factory throws `UnsupportedOperation: not supported by gRPC-web` on web.

- **`AuthInterceptor`** attaches the Firebase ID token to every call via `fb_auth.FirebaseAuth.instance.currentUser?.getIdToken()`. Token expires hourly; FirebaseAuth auto-refreshes — call `getIdToken()` per request, don't cache.

- **State management:** Riverpod (`flutter_riverpod`). `grpcClientsProvider` is a top-level `Provider`.

- **Firebase project ID** in `firebase_options.dart` must match `superwizor-ai-25ecd` (audience claim).

- **Web build limitation:** backend services are NOT yet `grpcweb.WrapServer`-wrapped. For day-to-day dev, use **iOS simulator** to bypass gRPC-Web. Web is needed for the future therapist registration portal.

- **Firestore** is **read-only** mirror of session status (per ADR-006). Subscribe to `session_state/{session_id}`. Don't store domain truth there. Backend writes via notification-svc (Phase 3).

- **Recording flow:** `RequestUploadTicket` → PUT to GCS via signed URL → `ConfirmUpload` → poll/subscribe for report.

- **Common gotchas:**
  - HTML 401 page on first call → Cloud Run IAM rejecting before app sees the request. Fix on infra (`allUsers` binding), not in Dart.
  - Direct GCS PUT must use the signed URL exactly; don't try to authenticate with user creds.
