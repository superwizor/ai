# 15 — Hybrid Eventarc-driven ingestion finalization (Option F)

**Status:** design (2026-05-25). Not started. Branch will be
`feat/ingestion-eventarc-finalize` when picked up.

**Predecessor:** `docs/14_INGESTION_EARLY_SESSION_CREATION.md`
(Option E "E-lite", shipped 2026-05-25 in merge `fae7c1a`). Option F
is the natural follow-up — the "E-full" variant called out as future
work in §"Open design choices" of the predecessor doc.

**Owner:** unassigned. Trigger to schedule: see §"When to ship" below.

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
                                  ┌────────────────────────────────┐
                                  │  ingestion-finalize            │
                                  │  (Cloud Functions Gen2,        │
                                  │   Eventarc-triggered)          │
                                  │                                │
                                  │  1. lookup audio_uploads by    │
                                  │     (bucket, object_path)      │
                                  │  2. if codec ≠ Chirp-supported │
                                  │     → ConvertAudio (transcode  │
                                  │       to FLAC in place)        │
                                  │  3. ffprobe duration           │
                                  │  4. if >19 min → ffmpeg        │
                                  │     silence-detect → write     │
                                  │     chunks to NEW chunked      │
                                  │     bucket; INSERT audio_chunks│
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

## Pipeline failure-mode comparison

| Scenario | Current (Option E-lite, shipped) | Option F |
|---|---|---|
| Flutter dies before PUT | No GCS object, audio_uploads PENDING + no session yet (Hive recovers on relaunch) | Same. Eventarc never fires because no PUT happened. |
| Flutter dies between PUT and CompleteAudioUpload | audio_uploads UPLOADED, GCS file present, session PENDING_UPLOAD. Hive recovers on relaunch → retries Complete. Hive-lost → stt-watchdog reaps the orphan PENDING_UPLOAD in ≤15 min. | **Closed structurally.** Eventarc fires on PUT regardless of Flutter state. ingestion-finalize completes the work even if the user uninstalls the app immediately after PUT. |
| Flutter dies between PUT and Convert | Same as above for Convert-needed clients (Android, web). | Same. ConvertAudio is now part of ingestion-finalize; no client involvement. |
| ConvertAudio retries fire concurrently | Server-side advisory lock in `maybeChunkForChirp` already handles concurrent calls. | Same lock + the new `ClaimUploadForFinalize` row-level guard. Two layers of protection. |
| Cloud Functions Gen2 cold start | N/A (Cloud Run keeps warm) | ~1–2 s added latency per upload. For a 30 s upload, ~5% impact on time-to-stt-start. For a 60 min upload, ~0.05%. |
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

- New `ingestion-finalize` Cloud Function. Container-image build
  (custom Dockerfile) so it can ship ffmpeg.
- New `audio-chunks-staging` GCS bucket + IAM for the
  ingestion-finalize SA.
- New Eventarc trigger on `audio-uploads` (OBJECT_FINALIZE).
- Migration `000026` for `audio_uploads.finalize_started_at` +
  unique index on `(bucket_name, object_path)`.
- Refactor of ffprobe + ConvertAudio + chunking out of
  `services/ingestion-svc/internal/adapters/grpc/server.go` into a
  reusable helper that both the legacy gRPC handler and the new
  Cloud Function import.

## Migration plan

| Day | Work |
|---|---|
| 1 | Migration `000026`: `finalize_started_at` column + `ux_audio_uploads_bucket_object`. Sqlc regen. |
| 2 | New shared `internal/adapters/storage/finalize.go` package — moves the body of `CompleteAudioUpload` into a function that takes `audio_uploads.ID` and runs the same ffprobe + Convert + chunking + publish sequence. Used by both the legacy gRPC handler and the new function. |
| 3 | `cmd/ingestion-finalize/main.go` — Cloud Functions Gen2 entrypoint. Eventarc → `ClaimUploadForFinalize` → call into shared finalize helper. |
| 4 | Terraform: new `audio-chunks-staging` bucket + IAM. New `google_cloudfunctions2_function "ingestion_finalize"` with Eventarc trigger on `audio-uploads`. Custom container source (Dockerfile mirrors ingestion-svc). |
| 5 | Update chunker (`storage/chunker.go`) to write to the staging bucket. stt-worker's chunk-plan reads `audio_chunks.bucket_name` already — no change needed there. |
| 6 | Flutter: collapse UploadWorker state machine to terminate at `uploaded`. Remove `CompleteAudioUpload` call from `upload_io_grpc.dart`. Update `_PendingUploadCard` status text to reflect the new shorter client-side flow. |
| 7 | Coordinated deploy: backend (ingestion-svc + ingestion-finalize + stt-worker) in one terragrunt apply, Flutter binary push after. Server keeps `CompleteAudioUpload` handler for ≥1 week so legacy clients work; new clients never call it. Watch logs for `legacy_complete_audio_upload_called` metric. |
| 8–14 | Deprecation window. After 7 days of zero `legacy_complete_audio_upload_called`, follow-up commit removes the handler + the proto field. |

Total: ~2 weeks of effort for one engineer including the deprecation
window. Roughly double Option E-lite's scope.

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
  Eventarc supports DLQs; we have one for the existing
  `audio.uploaded` topic. Should we wire a separate DLQ for
  `ingestion-finalize` events that exhaust retries (24 h, ~5
  attempts at exponential backoff)? Probably yes — surfaces
  "this upload's chunking can't succeed" cases for manual
  inspection. Same dashboard pattern we already have for
  `audio.uploaded.dlq.reader`.

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
