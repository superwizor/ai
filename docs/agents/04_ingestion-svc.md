---
type: Backend Service Specification
title: "ingestion-svc"
description: "The \"secure upload door\" + the async ingestion finalizer."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/agents/04_ingestion-svc.md
tags: [svc, ingestion, agents]
timestamp: 2026-05-25T18:11:17+02:00
---

# ingestion-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

The "secure upload door" + the async ingestion finalizer.

**Two responsibilities, one Cloud Run binary**:

1. **Synchronous gRPC** — issues V4 signed URLs to GCS so the Flutter
   app uploads audio **directly to Cloud Storage** (not through this
   service) and creates the matching `sessions` row in
   `PENDING_UPLOAD` status. Single RPC: `CreateAudioUpload`. Plus a
   debug helper `GetAudioUploadStatus`.

2. **Asynchronous in-process subscriber** (Option F,
   feat/refactor-stt-architecture, 2026-05-25) — a goroutine started
   from `cmd/server/main.go` pulls from the
   `audio.objectFinalized.sub` Pub/Sub subscription. Every GCS
   `OBJECT_FINALIZE` event on the audio-uploads bucket lands here.
   The subscriber probes duration via ffprobe, transcodes
   non-Chirp-supported codecs to FLAC via ffmpeg, runs silence-detect
   chunking on audio > 19 min, flips `sessions.status` from
   `PENDING_UPLOAD` to `CREATED`, and publishes the structured
   `audio.uploaded` event that downstream STT workers consume.

> The legacy `CompleteAudioUpload` and `ConvertAudio` RPCs were
> **removed** on 2026-05-25 along with the same-day `feat/refactor-stt-architecture`
> deploy. App is pre-launch so we updated every Flutter client in
> lockstep; no deprecation window. See
> [`docs/15_HYBRID_EVENTARC_FINALIZATION.md`](../15_HYBRID_EVENTARC_FINALIZATION.md)
> for the full design.

Why direct upload: 300 MB through Cloud Run = ~10 GB egress per 100
sessions + 15-minute request timeout. Both unacceptable.

Why a server-side subscriber instead of synchronous
`CompleteAudioUpload`: it decouples the Flutter HTTP PUT from
ffprobe + chunking work that takes 30–120 s on long audio. The
client terminates as soon as the GCS PUT returns 2xx; everything
else is server-driven.

## Status (2026-05-25)

- **Phase 2 + Option F — DONE.** Deployed at
  `https://ingestion-svc-...run.app`. Public, dedicated SA,
  min=1/max=20 instances, `--no-cpu-throttling --cpu=2 --memory=2Gi`
  so the pull-subscriber goroutine has sustained CPU between requests.
- Storage bucket lifecycle (OLM 48h) is configured at the bucket
  level, NOT in this service.
- The `audio.objectFinalized` topic + `audio.objectFinalized.sub`
  subscription + `google_storage_notification` on the audio-uploads
  bucket are terraform-managed; see `modules/pubsub` and
  `modules/storage`.

## Repo paths

```
services/ingestion-svc/
├── cmd/server/main.go               # entry point — starts gRPC server + subscriber goroutine
├── go.mod / go.sum / sqlc.yaml / Dockerfile
└── internal/
    ├── adapters/
    │   ├── grpc/server.go           # CreateAudioUpload, GetAudioUploadStatus
    │   ├── postgres/db/             # sqlc-generated
    │   ├── pubsub/
    │   │   ├── publisher.go         # publishes audio.uploaded (used by subscriber.go)
    │   │   ├── subscriber.go        # NEW (Option F) — pulls audio.objectFinalized.sub
    │   │   └── subscriber_test.go
    │   └── storage/                 # signed URL generator + ffmpeg converter + chunker
    └── domain/

proto/ingestion/v1/ingestion.proto
gen/go/ingestion/v1/
```

## gRPC API (Option F, 2026-05-25)

```protobuf
service IngestionService {
  rpc CreateAudioUpload(CreateAudioUploadRequest) returns (CreateAudioUploadResponse);
  rpc GetAudioUploadStatus(GetAudioUploadStatusRequest) returns (AudioUploadStatus);
}
```

The full contract is a clean two-RPC surface:

| RPC | When client calls it |
|---|---|
| `CreateAudioUpload` | Once, before the HTTP PUT. Returns `upload_id`, V4 signed URL + expiry, the GCS `object_path`, required headers, and the `session_id` of the newly created `sessions` row (status `PENDING_UPLOAD`). |
| `GetAudioUploadStatus` | Debug helper. Flutter normally polls via the Firestore `session_states/{sessionId}` mirror, not this RPC. |

After the PUT, **nothing on the client.** The GCS bucket
notification fires, the subscriber goroutine takes over.

### CreateAudioUpload contract

- Idempotent on `(therapist_id, idempotency_key)`. A retry with the
  same key returns the original `upload_id` + a fresh signed URL.
  This is how Flutter recovers from an expired URL without creating
  a duplicate `audio_uploads` row. The pre-check + post-INSERT
  unique-violation catch handle the race.
- Creates the `sessions` row in the same transaction as the
  `audio_uploads` row. Either both exist or neither.
- `sessions.status = 'PENDING_UPLOAD'` initially. The subscriber
  flips it to `CREATED` once the audio is on GCS + finalized.
- Object path: `{therapist_id}/{session_id}/{ts}.{ext}`. The
  subscriber parses this to recover the session_id from the GCS
  notification payload.

### The in-process subscriber

`internal/adapters/pubsub/subscriber.go` runs as a goroutine alongside
the gRPC server. Started from `cmd/server/main.go` when
`GCS_FINALIZE_SUB_ID` env is set (it always is in production —
points at `audio.objectFinalized.sub`).

For each pull message:

1. **Guard non-finalize events** — only handle `OBJECT_FINALIZE`.
   Malformed payload → ack-and-skip.
2. **Parse session_id** out of the object path. Path that doesn't
   match `{therapist_uuid}/{session_uuid}/...` → ack-and-skip
   (defensive: stray uploads outside the expected layout).
3. **Advisory lock** `SELECT pg_advisory_xact_lock(hashtextextended(session_id, 0))`
   inside a transaction. Serializes concurrent finalize attempts on
   the same session (rare; only if the bucket double-delivers).
4. **Status-branch idempotency**:
   - `PENDING_UPLOAD` → do the work below.
   - `CREATED` → republish `audio.uploaded` (recovery for the rare
     case where step 5 below committed but the Pub/Sub publish failed).
   - Anything past `CREATED` → ack-and-skip (already in flight or
     done; we never restart the pipeline).
5. **The work**: ffprobe duration → fallback transcode to FLAC if
   needed → if probed duration > 1140 s (19 min), run ffmpeg
   silence-detect + write `audio_chunks` rows → flip
   `audio_uploads.status` to `UPLOADED` → set
   `sessions.duration_seconds` → flip `sessions.status` to `CREATED`
   → commit (releases the advisory lock).
6. **Kickoff** `PublishAudioUploaded(session_id, upload_id, object_path)`
   on the `audio.uploaded` topic. stt-worker fans out from there.
7. **Ack** the pull message.

Failures inside step 5:
- ffmpeg / ffprobe non-zero on a corrupt source → mark
  `audio_uploads.status = FAILED`, flip `sessions.status = FAILED`,
  commit, ack. Terminal; we don't retry corrupt audio.
- DB / KMS / GCS 5xx → nack (let Pub/Sub redeliver). The advisory
  lock auto-releases on the rollback so the retry isn't blocked.

### Cloud Run config (critical)

The subscriber is a long-running background goroutine. By default
Cloud Run throttles CPU between requests, which starves the
goroutine and stalls ffprobe / ffmpeg mid-flight. The deploy
**must** pass `--no-cpu-throttling --cpu=2 --memory=2Gi`. CI's
`gcloud run deploy ingestion-svc` step does this; see
`.github/workflows/ci.yml`. Required env vars:

| Env | Value | Why |
|---|---|---|
| `GCP_PROJECT_ID` | `superwizor-ai-25ecd` | KMS, GCS, Pub/Sub clients |
| `AUDIO_BUCKET_NAME` | `superwizor-ai-25ecd-audio-uploads` | Signed URL signer + ffmpeg downloads |
| `DATABASE_URL` | from secret `postgres-database-url` | pgxpool |
| `GCS_FINALIZE_SUB_ID` | `audio.objectFinalized.sub` | Subscriber start gate |

Unsetting `GCS_FINALIZE_SUB_ID` disables the subscriber (kept as a
soft kill-switch). The gRPC server still runs; just no async
finalize happens. Don't ship to staging or prod with it unset.

### Client-side resilience: the Flutter upload queue

The Flutter app enqueues every upload — file-picker and
live-recording — into `lib/uploads/upload_queue.dart` (durable Hive
box) and walks it forward via `UploadWorker.runOne`. Implications
for this service:

- **`idempotency_key` is contract-critical.** Flutter reuses the
  same key across retries; the server must return the same
  `upload_id` + a fresh URL.
- **Signed-URL refresh.** On HTTP 401/403/410 (or the
  `400 ExpiredToken` shape), Flutter clears its credentials and
  re-runs `CreateAudioUpload` with the same key.
- **PUT-success is terminal on the client side.** The worker
  marks `phase=completed` the instant GCS returns 2xx; the server
  drives the rest.

### Orphan recovery (post-Option F)

The historical Hive-loss-orphan gap (PUT succeeded, then Flutter
state was wiped before `CompleteAudioUpload` could fire) is
**structurally closed** by Option F. The subscriber processes
OBJECT_FINALIZE events even when the Flutter app is uninstalled.
The narrow case that remains is a corrupt audio file that ffprobe
rejects — that surfaces in the session row as `FAILED` rather than
silently sitting in GCS.

There's still a Cloud Scheduler "ingestion-reaper" idea sketched
out for the case where the entire subscriber goroutine has been
down for hours and a backlog accumulates, but it's not built — the
DLQ on the pull subscription captures poison messages, and Pub/Sub's
7-day retention covers transient outages.

## Tables owned

| Table | Notes |
|---|---|
| `audio_uploads` | `PENDING` → `UPLOADED` → `FAILED`. `idempotency_key UNIQUE`, `expires_at = now() + 48h`. |
| `audio_chunks` | One row per silence-detect chunk for audio > 19 min. UNIQUE on `(audio_upload_id, chunk_index)`. |
| `sessions` (writes only) | Creates rows in `PENDING_UPLOAD`; subscriber flips to `CREATED` or `FAILED`. Owned by clinical-svc otherwise. |

> Source: `docs/02_DATA_MODEL.md` §4.6 + migrations `000007`,
> `000023` (audio_chunks), `000024` (UNIQUE on sessions.audio_upload_id),
> `000025` (PENDING_UPLOAD enum value).

## Signed URL contract

- **Method:** `PUT`
- **TTL:** scales with `estimated_size_bytes` (60 MB → 15 min,
  300 MB → 60 min — see `signer.go`). Long URLs let big uploads
  on slow networks complete before expiry.
- **Constraints:**
  - `Content-Type` matches `audio_uploads.content_type`.
  - `x-goog-content-length-range: 0,314572800` (max 300 MB).
- **Object path:** `{therapist_id}/{session_id}/{ts}.{ext}`
  (Option E + F).
- **Pre-flight:** ingestion-svc calls
  `billing-svc.CheckQuota(usage_type=session_analysis, amount=1)`
  before signing. Denied → `codes.ResourceExhausted`.

## Auth model

**Inbound:** public (`allUsers → roles/run.invoker`); Firebase ID
token validated in app layer.

**Outbound:**
- `identity-svc` (validate token).
- `billing-svc.CheckQuota` (Phase 2 stub returns true).
- GCS signed URL signing — dedicated SA
  `ingestion-svc@${PROJECT}.iam.gserviceaccount.com` with
  `roles/iam.serviceAccountTokenCreator` on itself.
- `roles/pubsub.publisher` on `audio.uploaded`.
- `roles/pubsub.subscriber` on `audio.objectFinalized.sub`.
- `roles/storage.objectAdmin` on the audio-uploads bucket.
- Cloud SQL.

## Key dependencies

- `identity-svc` (auth).
- `billing-svc` (quota gate).
- GCS bucket: `${PROJECT}-audio-uploads`.
- Pub/Sub topics: `audio.objectFinalized` (subscriber input),
  `audio.uploaded` (subscriber output).
- KMS — currently NO PHI columns in this service's tables.

## GCS lifecycle (OLM)

The bucket has a **dead-man-switch** policy: every object auto-deletes
after **48 hours** even if `stt-worker` never explicitly deletes it.
This is the P1 backstop — combined with at-least-once delivery, audio
that fails to transcribe still gets cleaned up.

`stt-worker` is responsible for explicit deletion AFTER successful
transcription (ADR-IMPL-006).

> Source: `docs/01_ARCHITEKTURA_TECHNICZNA.md` §7.2 (lines 737–774).
> Terraform: `infra/modules/storage/`.

## Constraining ADRs

| ADR | What it forces |
|---|---|
| **P1 (Zero Data Loss)** | Idempotency: `audio_uploads.idempotency_key UNIQUE` + retries. |
| **P2 (Zero Trust)** | Dedicated SA `ingestion-svc@`; explicit IAM bindings for GCS + Pub/Sub + Cloud SQL only. |
| **Direct-upload via signed URL** (architecture §4.2.4) | NEVER stream audio through this service. |
| **OLM 48h** (architecture §7.2) | Don't extend bucket lifetime past 48h. |

## GCP resources

| Resource | Notes |
|---|---|
| SA `ingestion-svc@` | `roles/storage.objectAdmin` on audio bucket, `roles/pubsub.publisher` on `audio.uploaded`, `roles/pubsub.subscriber` on `audio.objectFinalized.sub`, `roles/cloudsql.client`, `roles/iam.serviceAccountTokenCreator` (self-signing) |
| Cloud Run `ingestion-svc` | public, VPC connector, min=1, max=20, `--no-cpu-throttling --cpu=2 --memory=2Gi`, env `GCS_FINALIZE_SUB_ID=audio.objectFinalized.sub`, `DATABASE_URL` from secret |
| GCS bucket `${PROJECT}-audio-uploads` | OLM 48h, CMEK, `google_storage_notification` → `audio.objectFinalized` |
| Pub/Sub `audio.objectFinalized` | bucket notification target. Sub: `audio.objectFinalized.sub` (ack 600 s, max_attempts 5, DLQ `audio.objectFinalized.dlq`) |
| Pub/Sub `audio.uploaded` | published by the in-process subscriber; consumed by `stt-worker` + `notification-worker-on-uploaded`. DLQ: `audio.uploaded.dlq` |

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
  GCS_FINALIZE_SUB_ID=audio.objectFinalized.sub \
  go run ./cmd/server
```

Unsetting `GCS_FINALIZE_SUB_ID` locally is fine — the gRPC server
still runs and you can exercise `CreateAudioUpload`; you just won't
see the async finalize path.

## Iteration guardrails

**Safe to change:**
- Tweak signed-URL constraints (TTL, max size) — coordinate with
  Flutter expectations.
- Add validation rules to `CreateAudioUpload`.
- Add new fields to `audio_uploads` / `audio_chunks` (via migration).

**Careful:**
- Bucket name format change → must coordinate with stt-worker (which
  reads from the same bucket).
- GCS object path scheme → the subscriber parses
  `{therapist}/{session}/...` and stt-worker also parses it; coordinated
  change.
- `audio.uploaded` payload schema (`session_id`, `upload_id`,
  `object_path`) — contract with stt-worker.
- Subscriber concurrency — the v2 pubsub client's
  `MaxOutstandingMessages` default is generous; if you cap it, make
  sure long-audio chunking doesn't queue behind smaller jobs.

**Don't:**
- Stream audio through the service (ADR + architecture §4.2.4).
- Skip the `billing-svc.CheckQuota` call.
- Bypass `idempotency_key` on `audio_uploads`.
- Lengthen the GCS bucket OLM past 48 h.
- Disable `--no-cpu-throttling` on the Cloud Run deploy. The
  subscriber goroutine WILL stall mid-ffmpeg if you do, and you'll
  see endless Pub/Sub redeliveries on long audio.
- Re-introduce `CompleteAudioUpload` / `ConvertAudio` RPCs as
  client-driven endpoints. The architectural decision in Option F
  was to make this server-side-only; re-adding them brings back the
  Hive-loss orphan gap.

## Common gotchas

- **`pubsub` import:** must be `cloud.google.com/go/pubsub/v2`, not
  the deprecated v1. `client.Publisher(name)` (not `Topic`).
  `client.Subscriber(name)` (not `Subscription`). The v2 API rename
  bit subscriber.go on first compile.
- **`Publisher.Stop()`** must be deferred after every `Publish` —
  the v2 client's flush goroutine leaks each call without it.
- **The signed URL is signed by the SA, but the SA needs
  `iam.serviceAccountTokenCreator` on ITSELF** — counterintuitive
  but correct.
- **CORS on the bucket:** Flutter web uploads need explicit CORS
  config; native iOS/Android don't.
- **`expires_at` on `audio_uploads`** is set to `now() + 48h` at
  insert. Queries that filter `WHERE expires_at > now()` skip rows
  the OLM is about to reap.
- **CPU-throttled Cloud Run kills the subscriber.** Symptom: short
  audio uploads complete, long audio (> 5 min) sticks at
  `PENDING_UPLOAD` forever, Pub/Sub redelivers without progress
  ever appearing. Fix: `--no-cpu-throttling --cpu=2 --memory=2Gi`.

## Source-doc pointers

- `docs/15_HYBRID_EVENTARC_FINALIZATION.md` — Option F design.
- `docs/14_INGESTION_EARLY_SESSION_CREATION.md` — Option E (session
  row at CreateAudioUpload time).
- `docs/05_FAZA_2_INGESTION_AI.md` Sprint 2.2 — original Phase 2 spec
  (pre-Option E/F; superseded by 14 + 15 for the upload flow).
- `docs/01_ARCHITEKTURA_TECHNICZNA.md` §4.2.4 (lines 426–440), §7.2
  (lines 737–774), §7.3 (lines 775–834).
- `docs/02_DATA_MODEL.md` §4.6 (lines 1519–1738) — `audio_uploads`,
  `upload_tickets`.
- Migrations: `000007` (Phase 2 base), `000023` (audio_chunks),
  `000024` (UNIQUE sessions.audio_upload_id), `000025`
  (PENDING_UPLOAD enum value).
