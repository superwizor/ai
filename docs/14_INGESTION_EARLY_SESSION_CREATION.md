---
type: System Documentation
title: "14 — Ingestion: early session creation (Option E)"
description: "Status: issue, not started (2026-05-24). Tracked here. Branch will be feat/ingestion-early-session when picked up."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/14_INGESTION_EARLY_SESSION_CREATION.md
tags: [ingestion]
timestamp: 2026-05-24T22:18:03+02:00
---

# 14 — Ingestion: early session creation (Option E)

**Status:** issue, not started (2026-05-24). Tracked here. Branch
will be `feat/ingestion-early-session` when picked up.

**Owner:** unassigned.

**Estimated effort:** ~1 week for one engineer, single coordinated
deploy (proto + ingestion-svc + Flutter binary). Low risk if the
migration order is respected.

---

## Problem statement

`ingestion-svc.CompleteAudioUpload` is a multi-phase handler. For long
audio (> 1140 s, the chunking threshold) the phases are:

```
codec gate              ~5 ms
queries.CompleteAudioUpload (UPDATE)   ~5 ms
ffprobe (download + probe)             30–60 s
ConvertAudio chunking
  download source                      30–60 s
  ffmpeg silence-detect                60–180 s
  per-chunk ffmpeg extract + upload    30–60 s × N chunks
  INSERT audio_chunks
CreateSession (INSERT)                 ~5 ms   ← session_id first exists HERE
PublishAudioUploaded                   ~50 ms
```

Total for a typical 60-min FLAC: **3–10 min** of server-side work
between Flutter's PUT-finishing and the `sessions` row landing in
Postgres.

This shows up as a concrete UX bug. Therapist uploads a long audio
in "Wgraj Plik z Dysku" mode, returns to the kartoteka, opens the
patient sessions list — **and sees nothing for several minutes.**
The `clinical-svc.ListSessions` RPC returns the current state of the
`sessions` table; the row doesn't exist yet because CompleteAudioUpload
is still running ffmpeg.

The same problem applies to long-form recording (the
`recording_screen.dart` path). Both upload paths use the same
`UploadQueueRunner` Hive queue and the same four-RPC sequence:
`CreateAudioUpload → PUT → ConvertAudio? → CompleteAudioUpload`.
Whichever path enqueued the upload, the user sees the same gap.

## Band-aid (already shipped 2026-05-24)

`flutter-app/.../client_details_screen.dart` now renders a
placeholder `_PendingUploadCard` per in-flight upload, sourced from
the Hive queue via the new
`pendingUploadsForPatientProvider.family<…, String>`. A `ref.listen`
triggers `sessionsProvider.notifier.fetchSessions(patientId)` the
instant a pending row leaves the active set, so the real card
replaces the placeholder without a manual refresh.

This is the right long-term UX even after Option E lands — it
gives the user immediate feedback while the upload is genuinely
in flight. But it papers over the underlying server-side delay:
when the user sees the placeholder, the placeholder reads
"Przetwarzanie audio…" even though the audio finished uploading
30 seconds ago and the server is grinding through ffmpeg. The
sessions row simply doesn't exist yet.

## What Option E changes

Move `CreateSession` from `CompleteAudioUpload` to `CreateAudioUpload`.
Embed `session_id` in the GCS object path. After the change, the
sessions row exists from the moment the Flutter client receives the
signed URL — long before the PUT even starts.

### Today's pipeline (post Fix 1 + Fix 2, ingestion-svc rev 00064-8n8)

```
Flutter.UploadQueueRunner.enqueueAndKick(PendingUpload{sessionId: null})
            ↓
phase=created     ingestion.CreateAudioUpload({patient_file_id, ...})
                    → INSERT audio_uploads (session_id = NULL)
                    → return {upload_id, signed_url, object_path}
                      object_path = {therapist}/{patient_file_id}/{ts}.{ext}
            ↓
phase=uploaded    Flutter PUT to GCS
            ↓
phase=converted   ingestion.ConvertAudio (m4a→flac, optional)
            ↓
phase=completed   ingestion.CompleteAudioUpload
                    → ffprobe (~60 s download)
                    → if long: chunking (3–10 min)
                    → CreateSession ← session_id first exists HERE
                    → PublishAudioUploaded → stt-worker
                    → return {session_id}
```

### Option E pipeline

```
Flutter.UploadQueueRunner.enqueueAndKick(PendingUpload{sessionId: null})
            ↓
phase=created     ingestion.CreateAudioUpload({patient_file_id, ...})
                    → CreateSession   ← MOVED UP. session_id allocated NOW.
                    → INSERT audio_uploads (session_id = just-allocated)
                    → return {upload_id, session_id, signed_url, object_path}
                      object_path = {therapist}/{session_id}/{ts}.{ext}
                  Flutter stores session_id on the PendingUpload row.
                  Patient sessions list NOW returns this session row.
            ↓
phase=uploaded    Flutter PUT to GCS
            ↓
phase=converted   ingestion.ConvertAudio (unchanged)
            ↓
phase=completed   ingestion.CompleteAudioUpload
                    → ffprobe + chunking (unchanged)
                    → PublishAudioUploaded → stt-worker
                    → no CreateSession (already done)
```

User-visible result: the sessions list shows the new row within 5–50 ms
of `enqueueAndKick`, not 3–10 min. The placeholder card stays for the
duration of the *actual* in-flight work — honest UX.

## Schema changes

### 1. `session_status` enum: add `PENDING_UPLOAD`

```sql
ALTER TYPE session_status ADD VALUE 'PENDING_UPLOAD' BEFORE 'CREATED';
```

Lifecycle:
```
PENDING_UPLOAD → CREATED → TRANSCRIBING → MERGING → ANALYZING → COMPLETED
              ↘ FAILED (any transition; OLM cleans 48 h orphans)
```

- `PENDING_UPLOAD`: row exists, audio_uploads row exists, but PUT not
  confirmed. Server cannot kick STT.
- Transition `PENDING_UPLOAD → CREATED` happens at the end of
  `CompleteAudioUpload`.

UI implication: `ClientDetailsScreen` and any other session-list
query must filter `PENDING_UPLOAD` from the user-facing card list,
OR render it as the existing `_PendingUploadCard` placeholder. The
local Hive queue still drives the placeholder for the in-flight
phase, so visible behaviour does not change — the DB row is just
honestly labelled now.

### 2. `audio_uploads.session_id`

Already has `ux_sessions_audio_upload_id` partial UNIQUE INDEX
(migration 000024, shipped 2026-05-24 as Fix 1). The
idempotent-retry path in `CreateAudioUpload` extends naturally:
same `idempotency_key` returns the same `(upload_id, session_id)`
pair.

### 3. Object path format

`{therapist_id}/{session_id}/{ts}.{ext}` instead of
`{therapist_id}/{patient_file_id}/{ts}.{ext}`.

Forward-only — old `audio_uploads` rows keep their paths until
the 48 h OLM rule cleans them up. `stt-worker`'s path parser
needs a dual-mode read (try `session_id`, fall back to
`patient_file_id`) for the migration window — say 7 days — then
the fallback can be removed.

This also makes the bucket-notification-based orphan-recovery path
viable as a future enhancement (see Future work below).

## Backend changes

### `ingestion-svc/internal/adapters/grpc/server.go::CreateAudioUpload`

Today (lines 71–180-ish):

```
generate object_path → INSERT audio_uploads → signed URL → return
```

Option E:

```
1. preflight: GetSessionDefaultsForPatientFile (currently in CompleteAudioUpload)
2. INSERT sessions (status='PENDING_UPLOAD', session_number, name, ...)
3. INSERT audio_uploads with session_id set
4. generate object_path using session_id
5. signed URL → return {upload_id, session_id, signed_url, object_path}
```

Idempotency: the existing `audio_uploads.idempotency_key UNIQUE` (migration 000018) returns the cached row on retry. Extend the cached-response path to also fetch the linked session via the new
`GetSessionByAudioUploadID` query (also shipped with Fix 1).

### `ingestion-svc/internal/adapters/grpc/server.go::CompleteAudioUpload`

Drop the `CreateSession` block (lines 319–387 today). Drop the
`GetSessionDefaultsForPatientFile` lookups — they moved up. The
handler shrinks to:

```
codec gate → UPDATE audio_uploads + sessions.status='CREATED'
           → ffprobe → chunking → publish
```

### proto

```proto
message CreateAudioUploadResponse {
  string upload_id     = 1;
  string signed_url    = 2;
  string object_path   = 3;
  google.protobuf.Timestamp expires_at = 4;
  string session_id    = 5;   // ← NEW
}
```

### sqlc

New query `CreateSessionPendingUpload` for the new flow. Existing
`CreateSession` either stays for the migration window or is deleted
along with the `CompleteAudioUpload` block.

## Flutter changes

### Proto regen
After adding `session_id` to `CreateAudioUploadResponse`,
`buf generate ../../proto` from `flutter-app/superwizor/`.

### `lib/uploads/upload_worker.dart::runOne`

phase=created handler now captures the session_id:

```dart
case UploadPhase.created:
  final res = await io.createUpload(u);
  return u.copyWith(
    uploadId: res.uploadId,
    signedUrl: res.signedUrl,
    sessionId: res.sessionId,     // ← NEW; was set in phase=completed before
    phase: UploadPhase.created,
  );
```

### `lib/uploads/pending_upload.dart`

No schema change — `sessionId` already nullable. Just populated
earlier in the lifecycle.

### `lib/screens/client_details_screen.dart`

The `_PendingUploadCard` lifecycle simplifies:
- Today, dedup compares `pending.sessionId` against the server list
  to handle the brief window where Hive has sessionId but the server
  doesn't have the row yet.
- Under Option E, whenever Hive has sessionId, the server has the row.
  So dedup becomes: `pending.sessionId != null` AND
  `server has session_id` → suppress placeholder.
- Card becomes tappable from phase=created (sessionId set immediately)
  instead of only from phase=completed.

## Failure modes (post Option E vs current)

| Scenario | Today (post Fix 1+2) | Option E |
|---|---|---|
| Flutter dies before CreateAudioUpload | No server state. Hive `pending` retries on relaunch. | Same. |
| Flutter dies between CreateAudioUpload and PUT | audio_uploads orphan, no session. 48 h OLM clears (no GCS file). No UI exposure. | sessions PENDING_UPLOAD orphan + audio_uploads orphan. **Periodic cleanup job** scans `sessions WHERE status='PENDING_UPLOAD' AND created_at < now() - 1 h` and soft-deletes. UI hides PENDING_UPLOAD rows. |
| Flutter dies between PUT and CompleteAudioUpload | audio_uploads UPLOADED + GCS file orphan. Hive recovers on relaunch (≥99% case). Hive-lost is the catastrophe. | sessions + audio_uploads + GCS file orphan, but the GCS file is now **path-resolvable to session_id**. **Bucket-notification-based recovery becomes viable** (closes the orphan-Hive-lost gap that today's design cannot — see Future work). |
| Pub/Sub publish swallowed | Closed by Fix 2 — returns error, Flutter retries. | Same. |
| CreateAudioUpload network failure mid-request | Cached idempotency on `idempotency_key`. | Same — extended to return cached session_id. |
| Cloud Run crash mid-CompleteAudioUpload chunking | TX rollback, Hive retry safe (Fix 1). | Same. |
| Therapist views patient sessions during long upload | Today (pre-2026-05-24): empty list. With placeholder: friendly card, but no DB row. | Real session row visible immediately. Status `PENDING_UPLOAD` → UI maps to "Sesja w trakcie ładowania" + spinner. Identical visible behaviour to today's placeholder. |

One new failure mode: orphan `PENDING_UPLOAD` session rows. Cleanup
is simple (no GCS round-trips, just SQL DELETE), and the cleanup is
race-safe because PENDING_UPLOAD rows whose audio_uploads have been
UPLOADED are not deleted — they're advancing.

## Migration plan (1 week, one engineer)

| Day | Work |
|---|---|
| 1 | Migration 000025: add `PENDING_UPLOAD` to `session_status` enum. Sqlc regen. Add `CreateSessionPendingUpload` query. Unit tests. |
| 2 | Refactor `CreateAudioUpload` to allocate session_id. Update `CompleteAudioUpload` to skip CreateSession when already linked. Object path format change with dual-mode read in stt-worker. |
| 3 | Proto change: `session_id` in `CreateAudioUploadResponse`. Regen Go + Dart. Update `UploadWorker.runOne` to capture sessionId at phase=created. |
| 4 | `client_details_screen.dart`: UI maps `PENDING_UPLOAD` server-status to the same placeholder card the Hive queue already drives. Dedup logic adjusted. Other session-list screens audited. |
| 5 | Add orphan-session cleanup SQL job (nightly Cloud Scheduler → small Cloud Function or `gcloud sql` script). |
| 6–7 | Coordinated deploy (proto + ingestion-svc + Flutter binary). Validate against existing test fixtures (`TestFullSession_HappyPath`, `TestLongSession_…`). Watch the orphan-rate metric for a week before declaring done. |

## Future work this unlocks

Once `object_path = {therapist}/{session_id}/{...}`, the
`google_storage_notification` we removed in 2026-05-23 (see `04_ingestion-svc.md` "Historical note") can be **re-added on a
dedicated topic** (NOT `audio.uploaded` — keep that clean for the
structured event from ingestion-svc) with a small recovery
function that:

1. Parses the raw GCS event.
2. Extracts `session_id` from the object path.
3. Looks up the audio_uploads row; if `session_id IS NULL` (shouldn't
   happen post-Option E, but defensive) or status is still PENDING
   after a debounce window, runs the finalize work server-side.

This closes the orphan-GCS-file recovery gap **structurally** —
the bucket notification becomes useful instead of noise, because
the path now carries enough information to act on.

Not part of Option E itself; flagged here so we don't forget the
follow-up.

## Open design choices

These need a decision before kicking off:

1. **Session list UI for PENDING_UPLOAD**: hide entirely (rely on Hive
   placeholder), OR render as the existing `_PendingUploadCard` style?
   The latter is more honest (DB and UI agree) but requires the patient
   sessions endpoint to return PENDING_UPLOAD rows + the screen to
   filter/render them consistently with the Hive placeholder. The
   former is simpler.

2. **Should ConvertAudio (m4a→flac transcode) also move to
   `CreateAudioUpload`-time?** Currently the client calls it as a
   separate RPC between PUT and CompleteAudioUpload. Moving it earlier
   would simplify the worker phases but adds work to the latency-
   sensitive create path. Probably leave as-is.

3. **Migration order around bucket-notification re-enable**: do we
   ship Option E first then the bucket-notification cleanup function
   in a follow-up, or pair them? I'd recommend Option E first as a
   complete unit, then the bucket-notification work as a second
   small project once the path format is stable.

## Related

- ADR-IMPL-013 — orphan-recovery via Hive durability (≥99% case)
- `04_ingestion-svc.md` "Known recovery gap" — 2026-05-23
- `04_ingestion-svc.md` "Historical note" — bucket notification removed 2026-05-23
- Migration 000018 — `audio_uploads.idempotency_key UNIQUE`
- Migration 000024 — `ux_sessions_audio_upload_id` partial UNIQUE
- Commit `0d48eed` — `_PendingUploadCard` band-aid (2026-05-24)
