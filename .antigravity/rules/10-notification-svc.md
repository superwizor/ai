---
description: Loads when editing notification-svc (FCM push, Firestore mirror, Phase 3).
globs:
  - "superwizor-backend/services/notification-svc/**"
  - "superwizor-backend/proto/notification/**"
  - "superwizor-backend/gen/go/notification/**"
  - "superwizor-backend/migrations/*notification*.sql"
  - "firestore.rules"
  - "firestore.indexes.json"
alwaysApply: false
---

# notification-svc (Phase 3 — not yet built)

**Read [`docs/agents/10_notification-svc.md`](../../docs/agents/10_notification-svc.md) before editing.**
**Implementation plan: [`docs/08_FAZA_3_NOTIFICATIONS.md`](../../docs/08_FAZA_3_NOTIFICATIONS.md).**

Quick orientation:

- **Two workloads, one Go module:**
  1. `cmd/worker/` — Cloud Functions Gen2; subscribes to Pub/Sub (`audio.uploaded`, `transcript.completed`, `report.generated`); sends FCM + writes Firestore. **`package notificationworker`, no `func main()`.**
  2. `cmd/server/` — Cloud Run gRPC service; Flutter calls `RegisterFCMToken`/`RemoveFCMToken`/`GetUnreadCount`.

- **Tables owned:** `fcm_tokens` (multi-token per user, soft-delete on FCM `NotRegistered`), `notification_deliveries` (audit + idempotency key `${session_id}:${notification_type}`).

- **Firestore collections owned (and ONLY this service writes them):**
  - `session_states/{sessionId}` — live status mirror for Flutter listener.
  - `user_notifications/{uid}/inbox/{notifId}` — inbox items.
  - Architecture §6.3: this is the SINGLE backend writer to Firestore. Don't add Firestore writes elsewhere.

- **Constraining ADRs (Phase 3 introduces):**
  - **ADR-IMPL-008:** No WebSocket — Firestore listener with FlutterFire is enough.
  - **ADR-IMPL-009:** Firestore writes are best-effort. Failed writes go to `firestore-sync.dlq`; never block FCM or pipeline.
  - **ADR-IMPL-010:** Worker = Cloud Functions Gen2; Server = Cloud Run. Mirrors ai-pipeline-svc split.
  - **ADR-IMPL-011:** Multi-token per user; FCM multicast; soft-delete on `IsNotRegistered`/`IsInvalidArgument`.
  - **ADR-IMPL-012:** Phase 3 mirrors only 3 status transitions (uploaded, analyzing, done). TRANSCRIBING/FAILED deferred to Phase 4.
  - **ADR-IMPL-013:** FCM payload carries NO PHI. Title/body generic; data = session_id only.

- **Common gotchas:**
  - `therapistFirebaseUid` vs `therapistId`: Firestore rules check Firebase UID; `users.id` is a UUID. Write the Firebase UID, not PG UUID, into the doc.
  - `FCM SendMulticast` returns success even if individual tokens fail. Always iterate `batchResp.Responses`.
  - Idempotency key MUST be deterministic (`${session_id}:${type}`). Time-based keys break dedupe on Pub/Sub redelivery.
  - Cloud Functions Gen2 supports ONE trigger per function — three topics = three function resources, one source bundle.
  - **`firestore.rules` is a placeholder that expires 2026-05-28** — replace with the production rules from architecture §6.4 before launch.
  - Firebase Admin SDK with ADC needs `signBlob` IAM grant (same gotcha as the E2E test in `09_testing.md`).
