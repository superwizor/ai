# notification-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

Two responsibilities under one Go module:

1. **`notification-worker`** (Cloud Functions Gen2) — Pub/Sub-triggered. Subscribes to `audio.uploaded`, `transcript.completed`, `report.generated`. On `report.generated` sends FCM push to therapist's active devices. On every event, mirrors `sessions.status` to Firestore `session_states/{sessionId}` so Flutter listener gets live updates.
2. **`notification-svc`** (Cloud Run gRPC service) — Flutter calls this to register / refresh / remove FCM device tokens, and to query the inbox.

This is the **only** service allowed to write to Firestore from the backend (per architecture §6.3).

## Status (2026-05-09)

- **Phase 3 — DONE.** Cloud Run gRPC server + Cloud Functions Gen2 worker fully implemented and deployed via CI.
- **Server** (`cmd/server/main.go`, 108 lines): Firebase Auth + pgxpool + gRPC with `RegisterFCMToken`, `RemoveFCMToken`, `GetUnreadCount`, `HealthCheck`. Deployed with dedicated SA `notification-svc@` and `--allow-unauthenticated`.
- **Worker** (`cmd/worker/main.go`, 451 lines): Three CloudEvent handlers — `ProcessReportGenerated` (FCM multicast + Firestore mirror `done` + inbox doc + idempotency), `ProcessTranscriptCompleted` (status mirror `analyzing`), `ProcessAudioUploaded` (status mirror `uploaded`).
- **Adapters**: `internal/adapters/{fcm,firestore,grpc,postgres}` — all built.
- Pub/Sub topics wired (`audio.uploaded`, `transcript.completed`, `report.generated`).
- Firestore rules are **production-ready** (64 lines, per-user read, write denied, default deny). No expiration placeholder.
- **Not yet mirrored to Firestore:** `transcribing` and `failed` statuses (per ADR-IMPL-012, deferred to Phase 4). Flutter uses fallback poll to `clinical-svc.GetSessionDetails` for these.
- Implementation plan: [`docs/08_FAZA_3_NOTIFICATIONS.md`](../08_FAZA_3_NOTIFICATIONS.md).

## Repo paths (after Phase 3 build)

```
services/notification-svc/
├── go.mod / go.sum
├── Dockerfile                       # for the Cloud Run gRPC server
├── sqlc.yaml
├── cmd/
│   ├── server/main.go              # Cloud Run: RegisterFCMToken etc.
│   └── worker/main.go              # Cloud Functions Gen2: Pub/Sub handler(s)
└── internal/
    ├── adapters/
    │   ├── grpc/                    # gRPC server impl
    │   ├── postgres/db/             # sqlc-generated
    │   ├── firestore/               # session_states + user_notifications writers
    │   └── fcm/                     # Firebase Admin SDK wrapper
    └── domain/

proto/notification/v1/notification.proto
gen/go/notification/v1/
migrations/000009_notifications.up.sql       # fcm_tokens, notification_deliveries
```

## gRPC API

```protobuf
service NotificationService {
  rpc RegisterFCMToken(RegisterFCMTokenRequest) returns (RegisterFCMTokenResponse);
  rpc RemoveFCMToken(RemoveFCMTokenRequest) returns (google.protobuf.Empty);
  rpc GetUnreadCount(google.protobuf.Empty) returns (GetUnreadCountResponse);
  rpc HealthCheck(google.protobuf.Empty) returns (HealthCheckResponse);
}
```

Inbox listing isn't a gRPC call — Flutter subscribes directly to Firestore `user_notifications/{uid}/inbox/`. The service writes those docs; reads are client-direct.

> Source: `docs/08_FAZA_3_NOTIFICATIONS.md` Sprint 3.2 lines 246–298 — full proto with field descriptions.

## Tables owned

| Table | Purpose |
|---|---|
| `fcm_tokens` | Multi-token-per-user device registry. UNIQUE (user_id, token) where invalidated_at IS NULL. Soft delete on FCM `NotRegistered` or user logout. |
| `notification_deliveries` | Audit trail + idempotency key (`{session_id}:{notification_type}`). Status enum: `queued`, `sent`, `failed`, `token_invalid`. |

> DDL spec: `docs/08_FAZA_3_NOTIFICATIONS.md` Task 3.1.1.

## Firestore collections owned

| Collection | Doc shape | Writer | Reader |
|---|---|---|---|
| `session_states/{sessionId}` | `{sessionId, therapistFirebaseUid, status, progressPercent, updatedAt}` | notification-svc only (Admin SDK) | Flutter (rules: same uid as therapistFirebaseUid) |
| `user_notifications/{uid}/inbox/{notifId}` | `{type, sessionId, title, createdAt, readAt}` | notification-svc only | Flutter (own uid only); allowed to update `readAt` only |

Flutter has `allow write: if false` on both — Firestore rules enforce this. See architecture §6.4.

## Auth model

**Inbound (Flutter → gRPC server):** Public Cloud Run (`allUsers → roles/run.invoker`); Firebase ID token in `authorization: Bearer ...`. Handler resolves user via identity-svc.ValidateToken or local Firebase Admin SDK.

**Inbound (Pub/Sub → worker):** Eventarc trigger uses `notification-svc@<project>` SA identity; Pub/Sub service agent has `serviceAccountTokenCreator` on it (terraform-managed in `service-accounts.tf`).

**Outbound (worker):**
- Firebase Admin SDK → FCM (`roles/firebasecloudmessaging.messagesSender`).
- Firestore Admin SDK → `session_states`, `user_notifications` (`roles/datastore.user`).
- Cloud SQL via VPC connector for fcm_tokens / notification_deliveries.
- KMS — **NOT used.** No PHI columns in this service's tables (per ADR-IMPL-013, FCM tokens are opaque identifiers, not PHI).

## Key dependencies

- **Upstream Pub/Sub** — `audio.uploaded`, `transcript.completed`, `report.generated` (all in `infra/modules/pubsub/main.tf`, already deployed).
- **identity-svc** — to resolve users.id from Firebase UID for the gRPC server (or via local sqlc query on `users` table).
- **Firebase project** (`superwizor-ai-25ecd`) for FCM messaging.
- **Cloud SQL** for fcm_tokens / notification_deliveries.

## Constraining ADRs

| ADR | What it forces |
|---|---|
| **ADR-IMPL-008** | NO WebSocket. Firestore listener with FlutterFire is enough. Don't add a second protocol surface. |
| **ADR-IMPL-009** | Firestore writes are **best-effort**. A failed Firestore write must NEVER fail the FCM send or block the clinical pipeline. Failed writes go to `firestore-sync.dlq`; alert exists, deploy doesn't. |
| **ADR-IMPL-010** | Worker = Cloud Functions Gen2 (`package notificationworker`, no `main()`). Server = Cloud Run. Same split as `ai-pipeline-svc`. |
| **ADR-IMPL-011** | Multi-token per user; UNIQUE (user_id, token) with `WHERE invalidated_at IS NULL`. Soft-delete on FCM `NotRegistered`/`InvalidArgument`. Send to ALL active tokens via FCM multicast. |
| **ADR-IMPL-012** | Phase 3 mirrors only 3 status transitions to Firestore: `uploaded`, `analyzing`, `done`. `transcribing` and `failed` deferred to Phase 4 (would need a new `session.status_changed` topic). |
| **ADR-IMPL-013** | FCM payload carries NO PHI. Title/body localized generic strings. Data: `{session_id, notification_type}` only. Real content via clinical-svc.GetReport (KMS-decrypted). |
| **P1 Zero Data Loss** | Idempotency key on `notification_deliveries`: `${session_id}:${notification_type}`. INSERT ... ON CONFLICT DO NOTHING. Re-delivery from Pub/Sub at-least-once → no duplicate FCM. |
| **P4 Flutter read-only** | Firestore rules enforce `allow write: if false` on `session_states` and `user_notifications`. The only client-side write Flutter is allowed: `update` on its own `inbox/{notifId}.readAt` (diff check via `affectedKeys().hasOnly(['readAt'])`). |
| **§6.3 Backend-only Firestore writer** | This service is the **only** backend writer to Firestore. Don't add Firestore writes from clinical-svc, ai-pipeline-svc, or anywhere else. |

## GCP resources

| Resource | Notes |
|---|---|
| SA `notification-svc@<project>.iam.gserviceaccount.com` | runtime identity for both worker and server |
| IAM bindings | `cloudsql.client`, `secretmanager.secretAccessor` on `postgres-database-url`, `datastore.user`, `firebasecloudmessaging.messagesSender`, `eventarc.eventReceiver` |
| Pub/Sub service agent → token creator on this SA | so Eventarc can act as the worker |
| Cloud Run `notification-svc` | public, VPC connector, `--allow-unauthenticated` + `public_invoker` IAM via terraform (extend `local.public_cloud_run_services`) |
| Cloud Functions Gen2 worker(s) | Three trigger functions, one source bundle: `notification-worker-on-uploaded`, `-on-transcribed`, `-on-report`. Each binds to its own Eventarc trigger. |
| Firestore (default DB) | `(default)` instance in `europe-central2`. Rules deployed via `firebase deploy --only firestore:rules`. |
| FCM | enabled on Firebase project; no extra config beyond Admin SDK + `messagesSender` role |

## Local dev loop

```bash
cd services/notification-svc

sqlc generate
buf generate ../../proto

# Unit tests (after they exist)
go test ./...
golangci-lint run ./...

# Local server (gRPC API only — worker needs Pub/Sub which is hard to fake locally)
cloud-sql-proxy superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de --port=15432 &
DATABASE_URL="postgres://superwizor_app:$PASSWORD@127.0.0.1:15432/superwizor?sslmode=disable" \
  GCP_PROJECT_ID=superwizor-ai-25ecd \
  go run ./cmd/server
```

For the worker, simplest path: deploy to staging via `terragrunt apply -target=module.cloud_functions`, publish a fake `report.generated` Pub/Sub message via `gcloud pubsub topics publish`, watch logs.

## Iteration guardrails

**Safe to change:**
- Add new gRPC methods (e.g., `ListUserNotifications`, `MarkAllRead`).
- Add new sqlc queries.
- Tweak FCM message templates / localization.
- Add new Firestore field on `session_states` (additive).
- Refine retry / idempotency logic.

**Careful — touches contracts:**
- `session_states` doc shape — Flutter has live listeners. Field rename = client breakage. Additive changes only.
- `user_notifications` doc shape — same.
- Firestore rules — wrong rule = 403 in client, hard to debug. Always test with `firebase emulators:start` before deploy.
- Idempotency key format — changing `${session_id}:${type}` retroactively risks duplicate sends for in-flight messages.

**Don't:**
- Add a Firestore write from another service. **This service is the only writer** (architecture §6.3).
- Block the FCM send on a failed Firestore write. Best-effort.
- Put PHI in FCM payload. Title/body generic; data = session_id only (ADR-IMPL-013).
- Use `cloud.google.com/go/pubsub` v1 — always v2: `client.Publisher(name)`.
- Add `func main()` to `cmd/worker/` — it's `package notificationworker` for Cloud Functions Gen2.
- Send notifications to invalidated tokens. Filter `WHERE invalidated_at IS NULL` on every send.
- Hard-delete `fcm_tokens` rows. Soft-delete via `invalidated_at` so the audit trail (`notification_deliveries.target_token_id`) stays intact.

## Common gotchas

- **`therapistFirebaseUid` vs `therapistId`** — Flutter authenticates with Firebase UID, but `users.id` is a UUID. Firestore rules check `request.auth.uid == resource.data.therapistFirebaseUid`. **Write the Firebase UID into the doc, not the PG UUID.** Cross-mapping is via `users.firebase_uid`.
- **FCM `SendMulticast` returns success even if some tokens fail.** Always iterate `batchResp.Responses` and check `resp.Success` per-token. Mark token as `invalidated` only on `IsNotRegistered` / `IsInvalidArgument` errors — transient errors (network, quota) shouldn't invalidate.
- **Idempotency key must be deterministic.** `${session_id}:${notification_type}` is fine; `${session_id}:${time.Now().Unix()}` is a bug — Pub/Sub redelivery generates a new key, sends twice.
- **Cloud Functions cold start with Firebase Admin SDK** — ~1.5s on first invocation. Acceptable for batch flow; if needs faster, set `min_instance_count = 1`.
- **Multiple Eventarc triggers per function** — Cloud Functions Gen2 supports ONE trigger per function. To handle three topics: deploy three functions, same source bundle, three terraform resources.
- **Firebase Admin SDK + ADC + signBlob** — when invoked from a Cloud Function with no key file, the SDK falls back to `signBlob` IAM API. The runtime SA needs `serviceAccountTokenCreator` on `firebase-adminsdk-fbsvc@<project>` (same E2E test gotcha from `09_testing.md`). Add to `var.e2e_token_minters` or extend that pattern.
- **Firestore rules are production-ready.** The placeholder was replaced with 64-line production rules in `firestore.rules` — `session_states` (read own only, write denied), `user_notifications` (read own + update `readAt` only), default deny. No expiration date.
- **App in foreground vs background** — FCM iOS shows the system notification only if app is backgrounded; foreground app gets the message via `onMessage` callback and must show in-app UI. Document the FCM payload shape so Flutter's foreground handler renders correctly.

## Source-doc pointers

- `docs/08_FAZA_3_NOTIFICATIONS.md` — full implementation sprint plan (Definition of Done, ADRs, 6 sprints, smoke tests, troubleshooting cookbook).
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §4.2.7 (lines 466–475) — service responsibility spec.
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §6 (lines 631–724) — Firestore as sync layer (philosophy, doc shapes, rules, cost).
- `docs/03_DATA_MODEL.md` — notifications tables in migration 000009.
- `infra/modules/pubsub/main.tf` — topics (`audio.uploaded`, `transcript.completed`, `report.generated`) deployed.
- `firestore.rules` — production rules (64 lines, per-user read, default deny).
