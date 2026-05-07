# ingestion-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

The "secure upload door". Issues V4 signed URLs to GCS so the Flutter app uploads audio **directly to Cloud Storage** (not through this service). Records `upload_tickets`, then a GCS `OBJECT_FINALIZE` event flows through Eventarc → Pub/Sub `audio.uploaded` → ai-pipeline-svc's `stt-worker`.

Why direct upload: 300 MB through Cloud Run = ~10 GB egress per 100 sessions + 15-minute request timeout. Both unacceptable.

## Status (2026-05-07)

- **Phase 2 — DONE.** Deployed at `https://ingestion-svc-...run.app`. Public, dedicated SA, min=1/max=20 instances.
- Signed URL generation, ticket persistence, Pub/Sub publish are wired.
- Storage bucket lifecycle (OLM 48h) is configured at the bucket level, NOT in this service.

## Repo paths

```
services/ingestion-svc/
├── cmd/server/main.go               # entry point
├── go.mod / go.sum / sqlc.yaml / Dockerfile
└── internal/
    ├── adapters/
    │   ├── grpc/                    # RequestUploadTicket, ConfirmUpload, ...
    │   ├── postgres/db/             # sqlc-generated
    │   ├── pubsub/publisher.go      # publishes audio.uploaded (uses pubsub/v2)
    │   └── storage/                 # signed URL generator
    └── domain/

proto/ingestion/v1/ingestion.proto
gen/go/ingestion/v1/
```

## gRPC API

```protobuf
service IngestionService {
  rpc RequestUploadTicket(RequestUploadTicketRequest) returns (UploadTicket);
  rpc ConfirmUpload(ConfirmUploadRequest) returns (ConfirmUploadResponse);
  // (others in proto/ingestion/v1/ingestion.proto)
}
```

`UploadTicket` contains the V4 signed URL, the `upload_id`, and the GCS object path.

## Tables owned

| Table | Notes |
|---|---|
| `audio_uploads` | The state machine: `PENDING` → `UPLOADED` → `TRANSCRIBING` → `TRANSCRIBED` → `EXPIRED`. Has `idempotency_key UNIQUE`, `expires_at = now() + 48h`. |
| `upload_tickets` | Pending signed-URL grants; matches a `RequestUploadTicket` to a future `OBJECT_FINALIZE`. |

> Source: `docs/03_DATA_MODEL.md` §4.6 + `migrations/000007_phase2_ingestion.up.sql`.

## Signed URL contract

- **Method:** `PUT`
- **TTL:** 15 min
- **Constraints:**
  - `Content-Type: audio/m4a` (or `audio/aac`, `audio/mp4` — see `RequestUploadTicket` validation)
  - `x-goog-content-length-range: 0,314572800` (max 300 MB)
- **Object naming:** `audio_uploads/{therapist_id}/{patient_file_id}/{upload_id}.m4a` (or per Phase 2 spec; check current code).
- **Pre-flight:** ingestion-svc calls `billing-svc.CheckQuota(usage_type=session_analysis, amount=1)` before signing. If denied → return `codes.ResourceExhausted`.

> Source: `docs/02_ARCHITEKTURA_TECHNICZNA.md` §7.3 (lines 775–834).

## Auth model

**Inbound:** public (`allUsers → roles/run.invoker`); Firebase ID token in app layer.

**Outbound:**
- `identity-svc` (validate token, get user context).
- `billing-svc.CheckQuota` (Phase 2 stub returns true).
- Cloud Storage signed URL signing — uses dedicated SA `ingestion-svc@${PROJECT}.iam.gserviceaccount.com` with `roles/iam.serviceAccountTokenCreator` on itself (so it can sign URLs).
- Pub/Sub publish to `audio.uploaded`.
- Cloud SQL.

## Key dependencies

- `identity-svc` (auth)
- `billing-svc` (quota gate)
- GCS bucket: `${PROJECT}-audio-uploads`
- Pub/Sub topic: `audio.uploaded`
- KMS — currently NO PHI columns in this service's tables; if you add any, follow the envelope pattern.

## GCS lifecycle (OLM — Object Lifecycle Management)

The bucket has a **dead-man-switch** policy: every object is auto-deleted after **48 hours** even if `stt-worker` never explicitly deletes it. This is the P1 (Zero Data Loss) backstop — combined with at-least-once delivery, audio that fails to transcribe still gets cleaned up.

`stt-worker` is responsible for explicit deletion AFTER successful transcription (per ADR-IMPL-006: transcript blob in DB is canonical, audio is disposable).

> Source: `docs/02_ARCHITEKTURA_TECHNICZNA.md` §7.2 (lines 737–774). Terraform: `infra/modules/audio-storage/`.

## Constraining ADRs

| ADR | What it forces |
|---|---|
| **P1 (Zero Data Loss)** | Idempotency: `audio_uploads.idempotency_key UNIQUE` + retries. Don't reuse a key with different payload. |
| **P2 (Zero Trust)** | Dedicated SA `ingestion-svc@`; explicit IAM bindings for GCS + Pub/Sub publish only |
| **Direct-upload via signed URL** (architecture §4.2.4) | NEVER stream audio through this service. If you find yourself reading `req.AudioBytes`, you've broken the design. |
| **OLM 48h** (architecture §7.2) | Don't extend bucket lifetime past 48h — that's the explicit upper bound on PHI residence. |

## GCP resources

| Resource | Notes |
|---|---|
| SA `ingestion-svc@` | with `roles/storage.objectAdmin` on audio bucket, `roles/pubsub.publisher` on `audio.uploaded`, `roles/cloudsql.client`, `roles/iam.serviceAccountTokenCreator` (self-signing) |
| Cloud Run `ingestion-svc` | public, VPC connector, min=1, max=20, `DATABASE_URL` from secret |
| GCS bucket `${PROJECT}-audio-uploads` | lifecycle 48h, CMEK |
| Pub/Sub `audio.uploaded` | with DLQ `audio.uploaded.dlq`, retry 6 attempts |
| Eventarc trigger | `OBJECT_FINALIZE` on bucket → `audio.uploaded` topic → `stt-worker` Cloud Function |

## Local dev loop

```bash
cd services/ingestion-svc
sqlc generate
buf generate ../../proto
go test ./...
golangci-lint run ./...

# For local signed-URL testing you need real Application Default Credentials
gcloud auth application-default login
DATABASE_URL=... GCP_PROJECT_ID=superwizor-ai-25ecd \
  AUDIO_BUCKET_NAME=superwizor-ai-25ecd-audio-uploads \
  go run ./cmd/server
```

## Iteration guardrails

**Safe to change:**
- Add new endpoints (e.g., `ListUploads`, `CancelUpload`).
- Tweak signed-URL constraints (TTL, max size) — coordinate with Flutter client expectations.
- Add validation rules (e.g., reject uploads if therapist has no active session for that patient).

**Careful:**
- Bucket name format change → must coordinate with stt-worker (which reads from the same bucket).
- GCS object path scheme → stt-worker parses this; coordinated change.
- Pub/Sub message schema (`session_id`, `upload_id`, `object_path`) → contract with stt-worker; bump version, don't break existing consumers.

**Don't:**
- Stream audio through the service (see ADR + architecture §4.2.4).
- Skip the `billing-svc.CheckQuota` call (even in Phase 2 with stub).
- Bypass `idempotency_key` on `audio_uploads` — at-least-once delivery WILL deliver duplicates.
- Lengthen the GCS bucket OLM past 48h.

## Common gotchas

- **`pubsub` import:** must be `cloud.google.com/go/pubsub/v2`, not the deprecated v1. `client.Publisher(name)` (not `Topic`). See commit `fa9b4dd` for the fix.
- **`Publisher.Stop()`** must be deferred after every `Publish` — without it, the publisher's flush goroutine leaks each call. We added this in commit `fa9b4dd`.
- **The signed URL is signed by the SA, but the SA needs `iam.serviceAccountTokenCreator` on ITSELF** — counterintuitive but correct. Without it, signed URL generation returns `403 INVALID_ARGUMENT`.
- **CORS on the bucket:** Flutter web uploads need explicit CORS config on the bucket. Native iOS/Android don't.
- **`expires_at` on `audio_uploads`** is set to `now() + 48h` at insert. If your code path reads/inserts later than that for any reason, queries that filter `WHERE expires_at > now()` will skip the row.

## Source-doc pointers

- `docs/06_FAZA_2_INGESTION_AI.md` Sprint 2.2 (lines 767–1485) — full Phase 2 build spec.
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §4.2.4 (lines 426–440), §7.2 (lines 737–774), §7.3 (lines 775–834).
- `docs/03_DATA_MODEL.md` §4.6 (lines 1519–1738) — `audio_uploads`, `upload_tickets`.
- `migrations/000007_phase2_ingestion.up.sql` — actual DDL.
