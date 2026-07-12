---
type: System Documentation
title: "15 — Hybrid event-driven ingestion finalization (Option F)"
description: "Status: ✅ shipped 2026-05-25 on feat/refactor-stt-architecture. Backend + Flutter + terraform + e2e all landed in the same change. CompleteAudioUpload and Co..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/15_HYBRID_EVENTARC_FINALIZATION.md
tags: [ingestion]
timestamp: 2026-05-25T18:11:17+02:00
---

# 15 — Hybrid event-driven ingestion finalization (Option F)

**Status:** ✅ **shipped 2026-05-25** on
`feat/refactor-stt-architecture`. Backend + Flutter + terraform +
e2e all landed in the same change. `CompleteAudioUpload` and
`ConvertAudio` gRPC RPCs were **deleted** (no deprecation window;
app pre-launch).

**Note on the title:** the original draft of this doc used
"Eventarc-driven". The shipped implementation uses a plain
`google_storage_notification` → `audio.objectFinalized` Pub/Sub
topic → `audio.objectFinalized.sub` pull subscription consumed by
a background goroutine inside ingestion-svc — not the Eventarc
managed primitive. "Hybrid event-driven" is the more honest label.
The trigger source is still a GCS object event; we just skip the
Eventarc-to-Cloud-Function dance because the consumer lives in
Cloud Run.

**Predecessor:** `docs/14_INGESTION_EARLY_SESSION_CREATION.md`
(Option E "E-lite", shipped 2026-05-25 in merge `fae7c1a`). Option F
is the natural follow-up — the "E-full" variant called out as future
work in §"Open design choices" of the predecessor doc.

**Verification:**
- `TestFullSession_HappyPath` (40 s FLAC) — 215 s, PENDING_UPLOAD →
  TRANSCRIBING → MERGING → ANALYZING → COMPLETED, no client RPC after
  PUT.
- `TestLongSession_Chunked` (22-min, 103 MB FLAC) — 386 s end-to-end
  via the subscriber's silence-detect chunking path.
- All Patient lifecycle + Report preferences e2e green.
- 112 Flutter unit tests green.

**Operational note:** the Cloud Run service was deployed with
`--no-cpu-throttling --cpu=2 --memory=2Gi`. Default CPU-throttling
stalls the pull-subscriber goroutine between requests, which on
long audio causes Pub/Sub redeliveries without progress. Both the
CI workflow (`.github/workflows/ci.yml`) and the ingestion-svc
agent doc (`docs/agents/04_ingestion-svc.md`) call this out.

---

## Problem statement

After Option E shipped:

- Sessions appear in the kartoteka within ~50 ms of `CreateAudioUpload`.
- `CompleteAudioUpload` still synchronously does ffprobe + chunking +
  publish (3–10 min for a 60-min FLAC). Flutter's queue blocks on the
  RPC response for that duration.
- The remaining orphan-recovery gap (Flutter dies between PUT and
  CompleteAudioUpload AND Hive box is lost) is covered by the
  stt-watchdog reaper that runs every 15 min — narrow but real.
- Cross-device upload semantics (start on phone, see on tablet) only
  work after CompleteAudioUpload finally returns to the originating
  device, which writes the Firestore mirror.

Option F removes Flutter from the critical path after the PUT. The
GCS `OBJECT_FINALIZE` event drives a new server-side Cloud Function
that runs ffprobe + ConvertAudio + chunking + publish asynchronously.
Flutter walks away after the PUT; status updates flow through the
existing Firestore `session_states` mirror that `notification-worker`
already writes.

## End-state pipeline

```
Flutter:  CreateAudioUpload  ─────────→  PUT → GCS (audio-uploads bucket)
            │                                       │
            │                                       │
            ▼                                       ▼
  session (PENDING_UPLOAD)                  OBJECT_FINALIZE
  audio_uploads (PENDING)                          │
                                                   ▼
                                          Pub/Sub topic
                                          audio.objectFinalized
                                                   │
                                                   ▼
                                  ┌────────────────────────────────┐
                                  │  ingestion-svc                 │
                                  │  (existing Cloud Run service,  │
                                  │   new Pub/Sub pull consumer    │
                                  │   running in background        │
                                  │   alongside the gRPC server)   │
                                  │                                │
                                  │  1. lookup audio_uploads by    │
                                  │     (bucket, object_path)      │
                                  │  2. if codec ≠ Chirp-supported │
                                  │     → ConvertAudio (transcode  │
                                  │       to FLAC in place)        │
                                  │  3. ffprobe duration           │
                                  │  4. if >19 min → ffmpeg        │
                                  │     silence-detect → write     │
                                  │     chunks to audio-chunks-    │
                                  │     staging bucket; INSERT     │
                                  │     audio_chunks rows          │
                                  │  5. flip sessions.status       │
                                  │     PENDING_UPLOAD → CREATED   │
                                  │  6. publish audio.uploaded     │
                                  └────────────────────────────────┘
                                                   │
                                                   ▼
                                          stt-worker → Chirp
                                                   ▼
                                          stt-finalize → merge
```

Flutter's queue state machine collapses from 5 phases to 3:
`pending → created → uploaded` (terminal). Subsequent state
(`analyzing → done`) reaches the UI via the Firestore listener that
already exists (`session_states/{sessionId}`).

## Three concrete design refinements

These three decisions are pinned in this doc. The shipped version
of the doc may rephrase but must not depart from these constraints
without an updated doc.

### 1. Two buckets — `audio-uploads` and `audio-chunks-staging`

The Eventarc `OBJECT_FINALIZE` trigger lives on `audio-uploads`. Only
client-side PUTs land there:

- `audio-uploads/{therapist_id}/{session_id}/{ts}.{ext}` (Option E
  path layout from `fae7c1a`)

Server-side artifacts written during `ingestion-finalize` go to a
**separate bucket** so they don't re-trigger the same Eventarc:

- `audio-chunks-staging/{therapist_id}/{session_id}/chunk_{i}.flac`

Why a dedicated bucket beats event filtering:

| Option | Pros | Cons |
|---|---|---|
| Eventarc event filters (regex on objectId, exclude `_chunk_*`) | One bucket | Filters live in TF + Eventarc; opaque, easy to subtly break. Audit trail is "the trigger didn't fire" which is hard to observe. |
| Server filtering inside the handler | One bucket | Wakes the Cloud Function on every chunk write (cold start, log noise). The filtering itself is in code, code is reviewable, but every chunk = a wasted invocation. |
| **Two buckets** | Eventarc only fires on legitimate client PUTs. Server-side chunks are quietly written elsewhere. **No filter logic to maintain.** GCS lifecycle (OLM) can differ between the two — chunks live 7d, originals 48h. | One more GCS resource + IAM binding to manage. |

The two-bucket layout also keeps the **client-PUT and server-finalize
contracts** physically separate. Anything in `audio-uploads` was
written by a signed-URL client; anything in `audio-chunks-staging`
was written by `ingestion-finalize`. Operationally clearer.

Terraform additions:

```hcl
resource "google_storage_bucket" "audio_chunks_staging" {
  name          = "${var.project_id}-audio-chunks-staging"
  project       = var.project_id
  location      = "EUROPE-CENTRAL2"
  force_destroy = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  encryption { default_kms_key_name = var.app_data_key_id }
  lifecycle_rule {
    condition { age = 7 }    # 7 days — covers full STT + analysis window
    action { type = "Delete" }
  }
}
```

stt-worker's `chunk_plan` query changes minimally — it already
reads `audio_chunks.bucket_name` per row (no hardcoded bucket). The
chunker just writes the new bucket name into the rows.

### 2. ConvertAudio moves into `ingestion-finalize`

Today `ConvertAudio` is a separate gRPC that Flutter calls after PUT
when the client couldn't transcode locally (Android, web, edge-case
iOS). Under Option F, Flutter has no opportunity to call a
mid-stream RPC. ConvertAudio moves into `ingestion-finalize` and
fires conditionally at the head of the handler:

```go
// In ingestion-finalize, after lookup:
upload := lookupByObjectPath(bucket, objectPath)
if !storage.IsChirpSupported(upload.ContentType) {
    converted, err := converter.Convert(ctx, upload, "audio/flac")
    if err != nil { /* mark FAILED, ack */ }
    // converter.Convert atomically rewrites audio_uploads.object_path
    // + content_type. Subsequent ffprobe/chunking work uses the new path.
    upload = refetch(upload.ID)
}
// continue with ffprobe + chunking…
```

Implications:

- **ffmpeg becomes a dependency of the function image, not just
  ingestion-svc.** We already package ffmpeg in the
  ingestion-svc Cloud Run image (`Dockerfile`); the same approach
  works for Cloud Functions Gen2 by switching from the default
  buildpack runtime to a container-image build. The `ingestion-finalize`
  function uses a custom `Dockerfile` mirroring `ingestion-svc/Dockerfile`
  (debian:bookworm-slim + ffmpeg apt-install). Adds ~80 MB to the
  function image; Cloud Functions Gen2 supports up to 10 GB.

- **`ingestion-svc.ConvertAudio` RPC stays available for a deprecation
  window.** Flutter can still call it on legacy clients during the
  rolling-deploy window. Server-side, the gRPC handler becomes a thin
  shim that just runs the same `converter.Convert` path — the
  business logic moves into a shared package (`internal/adapters/storage/convert.go`)
  that both ingestion-svc and ingestion-finalize import.

- **Storage layout for converted output is unchanged.** ConvertAudio
  today rewrites the object in place (overwrites `{...}.m4a` with
  `{...}.flac` and updates the row). That still works — the
  transcoded object goes back to `audio-uploads` at the same
  `object_path` slot (minus extension change). Eventarc does NOT
  re-fire on this overwrite because GCS treats overwrites as new
  generations of the same object, and our Eventarc trigger filters
  on `OBJECT_FINALIZE` which fires on every generation. **Gotcha:** we
  need a self-guard inside the handler to detect "this finalize was
  triggered by my own ConvertAudio overwrite" and skip — see
  Idempotency below.

### 3. Idempotency on (bucket, object_path)

Eventarc is at-least-once. `ingestion-finalize` will receive
duplicate events for the same object — at minimum from Pub/Sub
redelivery, more often from ConvertAudio's overwrite generation.
The handler is fully idempotent on the natural key.

**Lookup-and-flip pattern** at the head of the handler:

```sql
-- New sqlc query: ClaimUploadForFinalize
UPDATE audio_uploads
SET finalize_started_at = now()
WHERE bucket_name = $1
  AND object_path = $2
  AND finalize_started_at IS NULL
  AND status IN ('PENDING')
RETURNING *;
```

This is the same "claim with FOR UPDATE / WHERE-NULL guard" pattern
we use in `stt-finalize.acquireMergeLock` and in `markChunkFinalized`.
- Zero rows affected → another invocation already started; ack and
  return.
- One row affected → we own the finalize; proceed.

Migration `000026` adds the column:

```sql
ALTER TABLE audio_uploads
  ADD COLUMN finalize_started_at TIMESTAMPTZ;

CREATE UNIQUE INDEX ux_audio_uploads_bucket_object
  ON audio_uploads(bucket_name, object_path);
```

The UNIQUE index serves two purposes:
1. Cheap `(bucket, object_path)` lookup — Eventarc events arrive with
   exactly those two fields.
2. Defensive constraint: a duplicate PUT (somehow) can't create a
   silent second row.

**ConvertAudio overwrite cycle handling.** When `ingestion-finalize`
calls `converter.Convert` and ffmpeg overwrites the .m4a with .flac at
the same path:
- The overwrite triggers a new `OBJECT_FINALIZE` event for the same
  `(bucket, object_path)` (object_path stayed the same — only ext
  changed when content_type changed).
- The new event reaches a second `ingestion-finalize` invocation.
- That invocation's `ClaimUploadForFinalize` finds
  `finalize_started_at IS NOT NULL` → returns 0 rows → second
  invocation acks and returns.

If ConvertAudio renames the file (.m4a → .flac, different
object_path), the new event hits a different (bucket, object_path)
than the original. To prevent this becoming "two finalize claims for
what's really one upload":
- ConvertAudio rewrites `audio_uploads.object_path` BEFORE the GCS
  delete of the old object. The new path's row entry already exists.
- Eventarc fires for the new path. `ClaimUploadForFinalize` finds the
  row but `finalize_started_at` is already set → ack and skip.

**Failure recovery.** If the handler crashes after claiming but before
completing:
- `finalize_started_at` is set, but `sessions.status` is still
  `PENDING_UPLOAD` and `audio_chunks` is empty.
- The orphan-cleanup pass in `stt-watchdog` can detect this with a
  small adjustment: `WHERE status='PENDING_UPLOAD' AND
  finalize_started_at < now() - interval '30 min'` → reset
  `finalize_started_at = NULL` so the next Eventarc retry (or a
  re-published event via gsutil) can re-claim. Eventarc retries with
  exponential backoff up to 24 h so a single crashed invocation
  doesn't need manual intervention.

**Exactly-once is impossible; effectively-once is the goal.** The
contract is: for any given `(bucket, object_path)`, at most one
invocation will reach the chunking + publish phase. All other
invocations short-circuit at the claim step. This is the same
contract `stt-finalize` already enforces against multi-chunk
finalize races; we're just extending the pattern.

### 4. Host the background subscriber inside ingestion-svc (Cloud Run)

The subscriber lives **in the existing `ingestion-svc` Cloud Run
container**, not as a separate Cloud Functions Gen2 deployment.

Implementation pattern: ingestion-svc startup spins up a Pub/Sub
**pull subscription** consumer as a background goroutine alongside
the existing gRPC server. The bucket notification on
`audio-uploads` publishes to a new `audio.objectFinalized` topic;
ingestion-svc has a pull subscription on that topic and processes
each delivery via the same `Finalize(...)` function used by the
gRPC `CompleteAudioUpload` shim during the deprecation window.

```go
// cmd/server/main.go (sketch)
func main() {
    // ... existing setup, db pool, signer, etc. ...

    srv := grpc.NewServer(/* ... */)
    ingestionv1.RegisterIngestionServiceServer(srv, handler)

    // NEW: background Pub/Sub consumer.
    consumerCtx, cancel := context.WithCancel(context.Background())
    defer cancel()
    go runFinalizeConsumer(consumerCtx, handler.Finalize)

    listenAndServeGrpc(srv, port)
}

func runFinalizeConsumer(ctx context.Context, finalize FinalizeFn) {
    sub := pubsubClient.Subscription("ingestion-finalize")
    err := sub.Receive(ctx, func(ctx context.Context, msg *pubsub.Message) {
        if err := handleObjectFinalized(ctx, msg, finalize); err != nil {
            // Don't Ack — Pub/Sub retries with backoff. Idempotent
            // handler covers redeliveries (§3 above).
            msg.Nack()
            return
        }
        msg.Ack()
    })
    if err != nil { slog.Error("finalize consumer crashed", "error", err) }
}
```

Why this beats a separate Cloud Function:

| Concern | Separate Cloud Function | In-process in ingestion-svc |
|---|---|---|
| Container image / Dockerfile | New custom-image build needed (ffmpeg layer ≈ 80 MB). Two Dockerfiles to maintain. | Already has ffmpeg. **Zero image work.** |
| Code reuse (`ConvertAudio` body, chunker, signer, db pool) | Requires extracting shared internal package — `internal/adapters/storage/finalize.go` — that both binaries import. Mechanical but non-trivial. | Handler is just another method on the existing `Server` struct. **Zero refactor.** |
| Cold start | ~1–2 s per invocation (Cloud Functions Gen2). | Zero — Cloud Run keeps `min_instance_count = 1`. |
| Service account | New SA + new IAM bindings (KMS, GCS, Pub/Sub publisher, Cloud SQL). | Existing `ingestion-svc@` SA already has everything needed. |
| Terraform surface | ~80 LoC: function resource, Eventarc trigger, IAM bindings, image build pipeline. | ~30 LoC: new Pub/Sub topic, new pull subscription on that topic, GCS bucket notification, one IAM binding (existing SA → subscriber). |
| Logging / observability | Separate log stream, separate error budget, separate alerts. | Single log stream tagged by `function="ingestion-finalize"` slog attribute. Existing alerts cover it. |
| Concurrency / load isolation | Cloud Functions scales horizontally per invocation. Two concurrent uploads = two function instances. | Cloud Run scales horizontally per instance load. `pubsub.Receive` defaults to processing up to `MaxOutstandingMessages = 1000` concurrently via goroutines; configure `NumGoroutines` / `MaxOutstandingMessages` to bound CPU contention with the gRPC server. **Not a problem in practice** — ffmpeg jobs are I/O-bound during download/upload and CPU-bound during transcode; with a sensible cap (say 4 concurrent finalize goroutines per instance) the gRPC latency-sensitive path is unaffected. |
| Crash blast radius | A finalize panic only kills the function instance; the gRPC service is unaffected. | A finalize panic killed by `recover()` middleware (already in place) doesn't propagate to the gRPC handlers. We need to verify the recovery middleware wraps the pubsub consumer goroutine too — it doesn't by default. **Action item.** |

Eventarc-to-Cloud-Run via HTTP push (the other in-process pattern)
would require adding an HTTP listener to a currently-gRPC-only
service — extra complexity for no benefit. Pull subscription
removes that: ingestion-svc speaks GCS / Pub/Sub / Postgres
outbound; no new inbound surface beyond the existing gRPC.

**One nuance: the bucket notification mechanism, not Eventarc.**
GCS supports two ways to publish object events to Pub/Sub:
- **Eventarc trigger** (managed; creates an internal topic, routes
  events through CloudEvents). Required for Cloud Functions; not
  required for Cloud Run with pull.
- **`google_storage_notification`** (direct; the bucket publishes
  raw `storage#object` JSON to a topic you own). Simpler, fewer
  moving parts, no CloudEvent wrapper to unmarshal.

We use **`google_storage_notification`** here. The same primitive
we removed earlier (when bucket-notification events flooded
`audio.uploaded` with raw GCS events nothing parsed; see
`04_ingestion-svc` "Historical note"). This time it's safe because:
- It publishes to a dedicated `audio.objectFinalized` topic, not
  the structured `audio.uploaded` topic.
- Only ingestion-svc subscribes; the consumer expects raw
  `storage#object` payloads (which is what GCS sends) and parses
  them into the `bucket, object_path` lookup.
- The chunked bucket (`audio-chunks-staging`) has no notification
  — chunk writes can't trigger this code path.

## Pipeline failure-mode comparison

| Scenario | Current (Option E-lite, shipped) | Option F |
|---|---|---|
| Flutter dies before PUT | No GCS object, audio_uploads PENDING + no session yet (Hive recovers on relaunch) | Same. Eventarc never fires because no PUT happened. |
| Flutter dies between PUT and CompleteAudioUpload | audio_uploads UPLOADED, GCS file present, session PENDING_UPLOAD. Hive recovers on relaunch → retries Complete. Hive-lost → stt-watchdog reaps the orphan PENDING_UPLOAD in ≤15 min. | **Closed structurally.** Eventarc fires on PUT regardless of Flutter state. ingestion-finalize completes the work even if the user uninstalls the app immediately after PUT. |
| Flutter dies between PUT and Convert | Same as above for Convert-needed clients (Android, web). | Same. ConvertAudio is now part of ingestion-finalize; no client involvement. |
| ConvertAudio retries fire concurrently | Server-side advisory lock in `maybeChunkForChirp` already handles concurrent calls. | Same lock + the new `ClaimUploadForFinalize` row-level guard. Two layers of protection. |
| Cold-start latency added per upload | N/A | **None** — host stays on warm ingestion-svc Cloud Run instance (min=1). |
| Eventarc storm on chunk writes | N/A | Mitigated by dedicated `audio-chunks-staging` bucket — Eventarc only listens to `audio-uploads`. |
| Cross-device upload completion | Phone A's CompleteAudioUpload return is the only signal that finalization started. Phone B sees PENDING_UPLOAD via Firestore mirror but no progression until A is done. | Eventarc finalize is server-driven. Phone B's Firestore listener observes `PENDING_UPLOAD → CREATED → TRANSCRIBING → …` independent of which device originated the upload. |

## What disappears

- `IngestionService.CompleteAudioUpload` RPC. Deprecated for one
  release, then removed in the follow-up.
- `IngestionService.ConvertAudio` RPC stays available for clients
  with cached old binaries during the deprecation window. Subsequent
  release removes it.
- Flutter `UploadWorker` phases `converted` and `completed`. The
  state machine becomes `pending → created → uploaded` (terminal),
  with subsequent progress observed via Firestore mirror.

## What gains complexity

- A new Pub/Sub topic (`audio.objectFinalized`) and pull
  subscription (`ingestion-finalize`) on it.
- A new `google_storage_notification` on `audio-uploads` pointing at
  that topic.
- New `audio-chunks-staging` GCS bucket + IAM binding for the
  existing `ingestion-svc@` SA.
- A new background goroutine inside ingestion-svc (`runFinalizeConsumer`)
  that pulls from the subscription. Must be wrapped in panic recovery
  matching the gRPC interceptor.
- Migration `000026` for `audio_uploads.finalize_started_at` +
  unique index on `(bucket_name, object_path)`.
- Refactor of ffprobe + ConvertAudio + chunking out of
  `CompleteAudioUpload` into a `Finalize(uploadID)` method on the
  existing `Server` struct, callable from both the legacy gRPC
  handler (during deprecation window) and the new pull-consumer
  goroutine.

What does **NOT** gain complexity vs. the separate-function variant:
no new container image, no new SA, no Eventarc trigger, no
CloudEvent unmarshaling code path. The shared-package extraction
becomes a same-package method extraction — much smaller PR.

## Migration plan

| Day | Work |
|---|---|
| 1 | Migration `000026`: `finalize_started_at` column + `ux_audio_uploads_bucket_object` unique index. New sqlc query `ClaimUploadForFinalize`. Sqlc regen. |
| 2 | Refactor: extract the body of `CompleteAudioUpload` (ffprobe → Convert → chunking → status flip → publish) into a `Server.Finalize(ctx, uploadID)` method. The existing gRPC handler becomes a thin shim that calls this method (kept during deprecation window). |
| 3 | New file `cmd/server/finalize_consumer.go`: `runFinalizeConsumer(ctx, finalizeFn)` — Pub/Sub pull subscription loop with panic recovery, configurable `MaxOutstandingMessages` (start with 4). Wire startup in `cmd/server/main.go` to spin up the goroutine alongside the gRPC listener. |
| 4 | Update chunker (`storage/chunker.go`) to write to the `audio-chunks-staging` bucket — accepts a `targetBucket string` parameter, defaults to the staging bucket name from env. stt-worker reads `audio_chunks.bucket_name` per-row already, so no change there. |
| 5 | Terraform: new `audio-chunks-staging` bucket, new `audio.objectFinalized` Pub/Sub topic (+ DLQ), new pull subscription `ingestion-finalize`, new `google_storage_notification` on `audio-uploads` → topic. IAM: `ingestion-svc@` gains `roles/pubsub.subscriber` on the new subscription and `roles/storage.objectAdmin` on `audio-chunks-staging`. |
| 6 | Flutter: collapse UploadWorker state machine to terminate at `uploaded`. Remove `CompleteAudioUpload` (and `ConvertAudio`) calls from `upload_io_grpc.dart`. Update `_PendingUploadCard` / `_PendingUploadServerCard` status text to reflect the new shorter client-side flow. |
| 7 | Coordinated deploy: one Cloud Build of ingestion-svc with the new consumer wired in, one terragrunt apply for the new TF resources, one Flutter binary push. Server keeps the `CompleteAudioUpload` and `ConvertAudio` gRPC handlers for ≥1 week so legacy clients work. Watch logs for `legacy_complete_audio_upload_called` + `legacy_convert_audio_called` counters. |
| 8–14 | Deprecation window. After 7 days of zero legacy-RPC counters, follow-up commit removes the handlers + the proto fields. |

Total: ~1.5 weeks of focused work for one engineer including the
deprecation window. Faster than the separate-Cloud-Function variant
(saved on Dockerfile, shared-package extraction, function-resource
TF) by ~3 days.

## When to ship

Don't ship now. Triggers that would re-prioritize:

- **Production orphan rate > 0.** If `stt-watchdog`'s
  `orphan_session_cleanup` log line shows non-zero deletions in real
  traffic, Option F closes that gap structurally.
- **Multi-platform clients land.** If we add a web frontend or
  therapist iPad app, the cross-device completion-visibility story
  matters and Option F is the cleanest answer.
- **Resumable uploads.** GCS resumable upload sessions pair much
  better with event-driven finalize than RPC-driven. If we add
  resumable PUTs for poor-network reliability (>200 MB recordings),
  Option F is the natural pairing.
- **Cloud Run timeout pressure.** If CompleteAudioUpload starts
  hitting its (currently 30-min) timeout on 90-min audio uploads, the
  Eventarc + Cloud Functions Gen2 path becomes load-isolated.

## Open questions for future work

- **ConvertAudio in-place rewrite vs. new object.** The current
  ConvertAudio overwrites the .m4a → .flac at the same path. Under
  Option F this is a clean idempotency story (rename triggers a
  new event that no-ops on the claim guard). But it means the GCS
  history shows two generations on the same object_path. Worth
  flagging in CR — alternative is to write the .flac to a new path
  and update audio_uploads.object_path (also produces a new
  Eventarc event, also handled by claim guard). Probably no
  behavior difference; pick whichever is cleaner to test.

- **What happens to `notification-worker-on-uploaded`?** Under
  Option E it consumes `audio.uploaded` Pub/Sub events that
  `CompleteAudioUpload` publishes. Under Option F those events are
  published by `ingestion-finalize` instead. No code change to
  notification-worker — same topic, same payload shape. Worth a
  one-line e2e check during day 7 validation.

- **Dead-letter queue / human-in-the-loop for finalize failures.**
  Pub/Sub supports DLQs at the subscription level. We have one for
  the existing `audio.uploaded` topic. Wire a separate DLQ for the
  new `ingestion-finalize` pull subscription that exhausts retries
  (`maxDeliveryAttempts = 6`, exponential backoff up to 600s).
  Surfaces "this upload's chunking can't succeed" cases for manual
  inspection. Same dashboard pattern we already have for
  `audio.uploaded.dlq.reader`.

- **Concurrency cap inside ingestion-svc.** With the consumer
  running in-process, ffmpeg jobs compete for CPU with the gRPC
  request handlers. Start with `MaxOutstandingMessages = 4` so at
  most 4 chunkings run concurrently per Cloud Run instance.
  Increase via env var if Cloud Run autoscaling needs the headroom.
  At the default cap, a typical 60-min FLAC chunking uses ~80% of
  one vCPU during silence-detect and ~120% during chunk extract +
  upload (the latter is I/O-bound + ffmpeg). With Cloud Run's
  `concurrency = 80` on the gRPC path, a single instance handling
  4 concurrent finalizes still has headroom for gRPC traffic. If
  this becomes a bottleneck, the path forward is bumping
  `min_instance_count` (already at 1) or breaking the consumer out
  into its own Cloud Run service (still no Cloud Function — just
  service split, same image).

- **Pull subscription liveness vs. Cloud Run scale-to-zero.** We
  keep `min_instance_count = 1` on ingestion-svc, so there's
  always one instance running the consumer goroutine. If the
  service ever scaled to zero (we shouldn't, but defensively), the
  Pub/Sub messages would queue on the topic with the subscription's
  default 7-day retention — no message loss, but no progress
  either. The min=1 invariant is load-bearing for Option F; a
  follow-up safety check in CI could assert `min_instance_count
  >= 1` on the ingestion-svc TF resource.

## Related

- `docs/14_INGESTION_EARLY_SESSION_CREATION.md` — Option E E-lite,
  shipped in `fae7c1a`. This doc's pre-requisite.
- `docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md` — the STT-side
  Eventarc pattern (stt-finalize) that this doc mirrors on the
  ingestion side.
- `services/ai-pipeline-svc/cmd/stt-watchdog/watchdog.go` — existing
  reaper pattern that the orphan-cleanup pass plugs into.
- `services/ingestion-svc/internal/adapters/storage/chunker.go` —
  ffmpeg silence-detect chunker; the body moves under Option F but
  the algorithm doesn't change.
