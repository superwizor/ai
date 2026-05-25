# ingestion-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

The "secure upload door". Issues V4 signed URLs to GCS so the Flutter app uploads audio **directly to Cloud Storage** (not through this service). Records `upload_tickets`, then on `CompleteAudioUpload` this service publishes a structured `{session_id, upload_id, object_path}` event to Pub/Sub topic `audio.uploaded` via `internal/adapters/pubsub/publisher.go::PublishAudioUploaded`. Downstream subscribers (ai-pipeline-svc `stt-worker`, notification-svc `notification-worker-on-uploaded`) pick that up.

> Historical note (removed 2026-05-23): the `audio_uploads` GCS bucket
> used to also have a `google_storage_notification` fan-out to the
> same `audio.uploaded` topic. That was the legacy STT-kickoff path
> from before ingestion-svc grew the explicit publisher, and it
> emitted raw `storage#object` JSON that no downstream subscriber
> could parse. `stt-worker` ack'd-and-ignored cleanly, but
> `notification-worker-on-uploaded` returned an error → Pub/Sub
> redelivered with backoff → the backlog delayed legitimate events
> by minutes on busy days. Removed via `infra/modules/storage/main.tf`.
> If you ever re-introduce a bucket notification, route it to a
> different topic.

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
  rpc ConvertAudio(ConvertAudioRequest) returns (ConvertAudioResponse);
  // (others in proto/ingestion/v1/ingestion.proto)
}
```

`UploadTicket` contains the V4 signed URL, the `upload_id`, and the GCS object path.

### ConvertAudio (added 2026-05-20)

Transcodes an uploaded audio file to FLAC 16 kHz mono **in place on
GCS** via ffmpeg shelled out from the Cloud Run instance. Used as a
fallback for clients that can't transcode on-device: Android (no
platform-channel impl yet), web, and iOS edge cases where
`AVAudioFile` fails to decode the source.

Flow:
1. Client calls `CreateAudioUpload(content_type=audio/m4a)` → PUT to GCS.
2. Client tries `convertM4aToFlac` on-device (Phase 1 — `flutter-app/superwizor/ios/Runner/AudioConverter.swift`). On failure / non-iOS, client uploads the **original M4A**.
3. Client calls `ConvertAudio(audio_upload_id)`. Server downloads, transcodes, uploads to a sibling `.flac` object, atomically updates `audio_uploads.object_path` + `content_type`, deletes the source object (OLM 48h backstop if delete races).
4. Client calls `CompleteAudioUpload` as normal — stt-worker now sees a FLAC and Chirp accepts it.

**Idempotent.** Re-calling on an already-Chirp-supported upload returns OK with `converted=false` and doesn't touch GCS.

**Synchronous.** Takes ~30–60s for a typical 60-min session. Cloud Run request timeout must be ≥ 300s (see infra).

**Failure modes:**
- ffmpeg non-zero (corrupt input) → `InvalidArgument` with truncated stderr (≤ 1 KB).
- GCS download fail → `Internal`/`Unavailable`.
- DB update fail after GCS upload → orphan: row points at .m4a, GCS has only .flac. Manual repair: `UPDATE audio_uploads SET object_path='.flac' WHERE id=...`. Logged loudly so Sentry surfaces it.

**Implementation:** `services/ingestion-svc/internal/adapters/storage/converter.go` (the ffmpeg shell-out + GCS streaming) + handler in `services/ingestion-svc/internal/adapters/grpc/server.go::ConvertAudio`.

### Client-side resilience: the Flutter upload queue (2026-05-21)

The Flutter app no longer drives the five RPC sequence inline. Every
upload — file-picker and live-recording — is enqueued into
`lib/uploads/upload_queue.dart` (durable Hive box) and walked
forward by `UploadWorker.runOne` one phase at a time. Implications
for this service:

- **`idempotencyKey` is contract-critical.** The Flutter client
  reuses the same key across CreateAudioUpload retries (it's stored
  on the `PendingUpload` row). The server MUST return the same
  `upload_id` + a fresh `signed_url` when called twice with the
  same key — that's how the client recovers from an expired URL
  without creating a duplicate `audio_uploads` row. Verified
  against migration 000007's `UNIQUE (idempotency_key)`.

- **Signed-URL refresh path.** When GCS returns 401/403/410 on PUT
  the client classifies as `signedUrlExpired`, clears the row's
  uploadId/signedUrl, and re-runs CreateAudioUpload. Don't break
  the idempotent return; don't issue a new upload_id.

- **ConvertAudio is idempotent on the client too.** The worker may
  call ConvertAudio more than once for the same `upload_id` if the
  app is killed between ConvertAudio and CompleteAudioUpload. The
  no-op return (`converted=false` when source is already
  Chirp-supported) handles this.

- **CompleteAudioUpload retries.** Same — the client retries with
  the same `upload_id` if the network drops between PUT/Convert and
  Complete. Don't fail-loud on "already completed"; surface
  `codes.AlreadyExists` only when the row genuinely transitioned
  past UPLOADED into TRANSCRIBING/TRANSCRIBED.

The client surfaces queue rows in a home-screen pill and a list
view (`lib/screens/pending_uploads_screen.dart`) so the user can
retry / dismiss failed rows manually. Errors that classify as
**terminal** (FAILED_PRECONDITION, INVALID_ARGUMENT, etc.) land
there with the gRPC error message intact — keep your error messages
actionable for the therapist who'll read them.

### Known recovery gap: orphaned GCS objects (2026-05-23)

There is **no server-side reaper** for the narrow case where the
GCS PUT succeeds but `CompleteAudioUpload` is never called *and*
the Flutter Hive box is also lost (uninstall, app-data wipe,
device switch). In that case:

- The file sits in `gs://<project>-audio-uploads/...` until the
  bucket's 48h OLM rule deletes it.
- `audio_uploads.session_id` stays NULL forever (the row exists
  from `CreateAudioUpload` but never advances).
- Nothing publishes `audio.uploaded` — the topic only carries
  events that ingestion-svc emits from inside `CompleteAudioUpload`.
- The recording is silently lost.

What **is** covered (no further work needed):
- App crash / OS kill / network drop / phone reboot between PUT
  and `CompleteAudioUpload`. Hive box persists every phase
  transition (see `upload_worker.dart:77-95`); on next launch
  `UploadQueueRunner` re-walks the queue and calls the missing
  RPC. This is the ≥99% case.

What is **NOT** covered:
- Hive box loss (uninstall / clear-app-data / new device with
  same account but no migration).
- `ingestion-svc.PublishAudioUploaded` failing silently while
  the row + GCS object are otherwise consistent (it logs+continues
  at server.go:391-393 today; no retry, no Pub/Sub publish
  exactly-once guarantee).

Historical note: the `audio_uploads` bucket used to have a
`google_storage_notification` fan-out to the same `audio.uploaded`
topic. That was sometimes mistaken for a recovery hook, but it
never functioned as one — the raw `storage#object` payload has
no `session_id` (the session row isn't created until
`CompleteAudioUpload`, which fires *after* OBJECT_FINALIZE), so
`stt-worker` always dropped these events (`main.go:140-143`) and
`notification-worker` choked on them. Removed 2026-05-23.

If/when this gap matters, the symmetric solution is a Cloud
Scheduler "ingestion-reaper" job (analogous to `stt-watchdog`):

```sql
SELECT id, bucket_name, object_path, therapist_id, patient_file_id
FROM audio_uploads
WHERE created_at < now() - interval '1 hour'
  AND session_id IS NULL
```

For each row: confirm the GCS object exists (it does → PUT
landed but Complete didn't), then run the same server-side
finalize that `CompleteAudioUpload` would have done (create
session, publish structured `audio.uploaded`, mark
`audio_uploads.session_id`). Idempotent against a late Flutter
queue retry because the `session_id IS NULL` filter naturally
drops rows the client already finished. Not built yet — file an
issue if the orphan rate becomes nonzero.

### CompleteAudioUpload codec gate (added 2026-05-20)

Defense in depth for the M4A flow. `CompleteAudioUpload` now fetches
the row BEFORE flipping status to UPLOADED and rejects unconverted
non-Chirp codecs with `codes.FailedPrecondition`. The error message
points the client at the remediation RPC by name and includes the
offending codec.

Catches: client uploads M4A, network hiccups between PUT and
ConvertAudio, client retries from CompleteAudioUpload without
re-running ConvertAudio. Without the gate, the M4A row would reach
stt-worker, Chirp would reject it, and Pub/Sub would retry 6×.

Uses `storage.IsChirpSupported` — the same allow-list (FLAC, WAV,
WAV/x-wav, OGG, Opus, WebM, AMR, AMR-WB). Keep this list in sync with
the rejection site in `ai-pipeline-svc/cmd/stt-worker/main.go`.

**Dockerfile change:** runtime base switched from `distroless/static-debian12:nonroot` to `debian:bookworm-slim` because distroless has no shell + no apt. Net image growth ~80 MB (ffmpeg itself is ~50 MB).

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
| Pub/Sub `audio.uploaded` | published by `ingestion-svc.PublishAudioUploaded` inside `CompleteAudioUpload`; consumed by `stt-worker` + `notification-worker-on-uploaded`. (No bucket notification — the GCS object path has no `session_id` since the session is created during CompleteAudioUpload, *after* OBJECT_FINALIZE fires, so a raw GCS event could never carry one.) |

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
