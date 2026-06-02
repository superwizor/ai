# Design: Resumable audio upload (client ↔ GCS)

Status: proposed. Replaces the single-shot PUT upload with a GCS **resumable
upload** so large recordings survive flaky networks and the object is
finalized exactly once.

## 1. Problem & goals

Today `CreateAudioUpload` returns a V4 **single-PUT** signed URL
(`signer.go:69`, `Method: http.MethodPut`) and the Flutter worker uploads the
whole file in one HTTP PUT (`upload_io.dart`), refreshing the URL on expiry
and **retrying the entire PUT** on any failure.

Two production failures (session `f97ebdab`, 2026-06-02) trace to this:

- **68-minute stall.** A drop at N% restarts from byte 0. On a weak link that
  can't sustain the connection long enough to finish, the upload never
  converges — it loops, refreshing the signed URL (`CreateAudioUpload` at
  17:12 / 17:47 / 18:20) and re-uploading from scratch.
- **Duplicate `OBJECT_FINALIZE` storm.** GCS finalizes the object at the end
  of *each* completed PUT. A "false-failure" retry (PUT times out client-side
  but lands server-side) writes a new object generation → a new
  `OBJECT_FINALIZE` → the ingestion subscriber's republish-on-`CREATED`
  amplifies it into multiple stt-worker invocations (idempotent, but wasteful
  and noisy — see docs analysis 2026-06-02).

### Goals
- Uploads **resume** after interruption (upload only the missing bytes).
- The object is **finalized exactly once** per logical upload.
- **Real progress** (`bytesSent/total`) for the "Wgrywanie" UI.
- No signed-URL-expiry refresh loop.
- Backward compatible — old app versions keep working during rollout.

### Non-goals
- On-device compression (complementary; tracked separately — it shrinks the
  file but doesn't make the transport reliable).
- Changing anything downstream of `OBJECT_FINALIZE` (subscriber, STT, LLM
  stay as-is; they just see one clean finalize).

## 2. Overview

Use the **GCS resumable upload protocol**:

1. **Initiate** a resumable session for the object → a **session URI**.
2. **Upload in chunks** with `Content-Range: bytes a-b/total`; GCS returns
   `308 Resume Incomplete` between chunks and `200/201` on the final chunk
   (which is when the object is committed and `OBJECT_FINALIZE` fires — once).
3. **Resume** after any interruption by querying `Content-Range: bytes */total`
   to learn the last byte GCS holds, then sending only the remainder.

The session URI lives ~1 week, so no per-attempt URL refresh.

**Who initiates?** Server-initiated (recommended): ingestion-svc starts the
resumable session with the service-account credentials and returns the
**session URI** to the client. The session URI is a capability scoped to that
one object with a finite lifetime — same trust model as today's signed URL,
just longer-lived and resumable. (Alternative in §9.)

## 3. API changes (`ingestion.proto`)

Extend `CreateAudioUploadResponse` — keep the existing fields for back-compat:

```proto
message CreateAudioUploadResponse {
  string upload_id = 1;
  string signed_url = 2;                       // legacy single-PUT; still set
  google.protobuf.Timestamp signed_url_expires_at = 3;
  string object_path = 4;
  map<string,string> required_headers = 5;
  string session_id = 6;

  // NEW — resumable upload. When non-empty the client MUST use this and
  // ignore signed_url. Old clients ignore these fields and keep using
  // signed_url, so rollout is safe.
  string resumable_session_uri = 7;            // GCS resumable session endpoint
  google.protobuf.Timestamp resumable_expires_at = 8;  // ~7 days out
  int64 recommended_chunk_size_bytes = 9;      // multiple of 256 KiB, e.g. 8 MiB
}
```

`CreateAudioUploadRequest` is unchanged (it already carries
`content_type`, `estimated_size_bytes`, `estimated_duration_seconds`,
`idempotency_key`).

**Idempotency:** the existing `idempotency_key` already maps one logical
upload → one `audio_uploads` row → one `object_path` → one `session_id`. A
retried `CreateAudioUpload` with the same key must return the **same**
`resumable_session_uri` if still valid, or initiate a fresh session for the
**same object_path** if the prior one expired (see §6 resume-after-restart).
Persist the session URI + its expiry on the `audio_uploads` row.

## 4. Server design (ingestion-svc)

### 4.1 Initiate the resumable session
New method on the storage adapter, alongside `GenerateUploadURL`:

```go
// StartResumableSession POSTs x-goog-resumable:start for objectPath and
// returns the session URI + expiry. Uses the SA creds (server-side only).
func (s *Signer) StartResumableSession(
    ctx, objectPath, contentType string, estSize int64,
) (uri string, expires time.Time, err error)
```

Implementation options (pick one):
- **`storage.Writer` with `ChunkSize` + resumable** — the Go GCS client's
  `Writer` does resumable uploads, but it expects the *server* to stream the
  bytes. We don't want that (the client has the bytes). So instead:
- **Raw initiate**: POST to
  `https://storage.googleapis.com/upload/storage/v1/b/<bucket>/o?uploadType=resumable&name=<obj>`
  with an OAuth token from the SA, headers `X-Upload-Content-Type`,
  `X-Upload-Content-Length` (if known), and object metadata
  (`x-goog-meta-source`, optional md5). GCS responds `200` with a `Location:`
  header = the **session URI**. Return that URI to the client.
  - Set `ifGenerationMatch=0` semantics by passing object precondition so the
    session only creates a brand-new object (defends against accidental
    overwrite of an already-finalized object on a stale retry).

Set `resumable_expires_at` ≈ now + 7d (GCS session lifetime; treat as the
client's hard deadline to finish).

### 4.2 Handler wiring
`CreateAudioUpload`:
1. Reserve billing + create/lookup `audio_uploads` row by `idempotency_key`
   (unchanged).
2. If the row has a live `resumable_session_uri` → return it.
   Else `StartResumableSession(...)` → persist URI + expiry on the row → return.
3. Keep emitting `signed_url` too (legacy clients).

### 4.3 audio_uploads schema
Add nullable columns (migration):
- `resumable_session_uri TEXT`
- `resumable_session_expires_at TIMESTAMPTZ`

(No change to the `OBJECT_FINALIZE` → subscriber path.)

## 5. Client design (Flutter `uploads/`)

### 5.1 `PendingUpload` additions
- `String? resumableSessionUri`
- `DateTime? resumableExpiresAt`
- `int bytesUploaded` (persisted — survives app kill so we can resume)
- `int chunkSizeBytes`

These live in the Hive-persisted queue row so a force-kill mid-upload resumes
on next launch instead of restarting.

### 5.2 The resumable worker (replaces the single PUT in `upload_io.dart`)
State machine stays `pending → created → uploaded`, but `created → uploaded`
becomes a loop:

```
ensureSession():
  if resumableSessionUri == null || expired -> CreateAudioUpload() to (re)issue
  // server returns the same object_path; a fresh session is fine, GCS lets
  // us re-query offset against the new session only if same object — so on a
  // brand-new session start bytesUploaded from 0 (rare: only when URI expired).

resume():
  PUT sessionUri, header `Content-Range: bytes */<total>`, empty body
  -> 308 with `Range: bytes=0-K`  => bytesUploaded = K+1
  -> 200/201                      => already complete, go to `uploaded`
  -> 404/410                      => session gone; re-initiate, bytesUploaded=0

uploadLoop():
  while bytesUploaded < total:
    end = min(bytesUploaded + chunkSize, total) - 1
    PUT sessionUri, body = file[bytesUploaded..end],
        header `Content-Range: bytes <bytesUploaded>-<end>/<total>`
    -> 308: bytesUploaded = parseRange(resp) + 1; persist; emit progress
    -> 200/201: bytesUploaded = total; phase=uploaded; done
    -> 5xx / network: backoff, then resume() to re-sync offset, retry
```

- **Streamed body** (don't load the whole file into memory): read the chunk
  byte-range from the file via a `RandomAccessFile`/stream.
- **Progress**: after each `308`, update `bytesUploaded` in the queue row →
  the "Wgrywanie" screen shows `bytesUploaded/total`.
- **Persistence**: persist `bytesUploaded` after each chunk ack so an app
  kill resumes from the last acked offset.

### 5.3 Error classification (`upload_error.dart`)
Map HTTP outcomes:
| Response | Class | Action |
|---|---|---|
| `308` | progress | continue loop / update offset |
| `200/201` | done | phase → `uploaded` |
| `503/500/429`, network drop | retryable | backoff → `resume()` → retry chunk |
| `404/410` (session gone/expired) | session-expired | re-`CreateAudioUpload`, reset offset |
| `400` w/ invalid range | recoverable | `resume()` to re-sync the offset |
| `403` (auth/expired URI) | session-expired | re-`CreateAudioUpload` |

Note: with resume, **retries never restart the whole file**, so the
`signedUrlExpired → full re-PUT` path is gone; the worst case is re-sending one
in-flight chunk.

### 5.4 Encrypted-chunk source
The existing `chunkCount`/encrypted-chunks path (for the
`needsServerSideConversion` / chunked source) maps cleanly: the resumable
`Content-Range` chunking is independent of the app's logical encryption chunks
— the worker just streams the assembled bytes by byte-range. Keep the existing
content assembly; only the transport changes.

## 6. Resume-after-app-restart
On launch, for any queue row in `created`/`uploaded`-pending:
1. If `resumableSessionUri` valid → `resume()` to learn the server offset →
   continue the loop. **No bytes re-sent** beyond the last unacked chunk.
2. If the session URI expired → `CreateAudioUpload` returns the same
   `object_path`; start a fresh session and re-upload (rare — only after ~7d
   idle). Because we use create-once precondition, this can't duplicate a
   finalized object.

## 7. Exactly-once finalize (the storm fix)
- The object commits **only** on the final chunk's `200/201`. Mid-upload
  chunks and resumes do **not** finalize → exactly one `OBJECT_FINALIZE`.
- Belt-and-suspenders (cheap, independent): make the ingestion subscriber
  **dedup by object `generation`** — record the processed generation on
  `audio_uploads` and ack stale/duplicate generations without re-publishing.
  This also protects against GCS's at-least-once notification duplicates.
- Optional: make republish-on-`CREATED` conditional (only if no
  `stt_operations` rows yet) so a duplicate never re-fans the STT kickoff.

## 8. Observability
- Client: emit upload progress (`bytesUploaded/total`, throughput) and a
  `upload_resumed` event count (how often resume kicks in — a network-health
  signal). Ties into the analytics plan (docs/24) — non-PHI.
- Server: count `OBJECT_FINALIZE` per `object_path` (should be 1); alert if >1.
- Keep the stt-worker `submit race` log as a regression canary — it should
  disappear once finalize is exactly-once.

## 9. Alternatives considered
- **Signed resumable-initiate URL** (sign a POST `x-goog-resumable:start` URL;
  client initiates and gets the session URI). Keeps SA fully out of the
  request path but adds a client round-trip + more client logic. Chosen
  server-initiated for simpler/faster client and one fewer round-trip; the
  session URI's trust model is equivalent to today's signed URL.
- **Keep single-PUT, just bump TTL + add client retry-resume via Range on the
  same signed URL.** GCS single-PUT signed URLs are *not* resumable — Range
  resume requires the resumable protocol. Rejected.
- **TUS / third-party resumable lib.** Unnecessary; GCS resumable is native.

## 10. Rollout & sequencing
1. **Server, additive** (1 PR): migration (2 columns) + `StartResumableSession`
   + `CreateAudioUpload` returns the new fields *in addition to* `signed_url`.
   Ship dark — no client uses it yet. e2e: a Go test that initiates a session,
   PUTs 2 chunks with `Content-Range`, resumes mid-way, verifies one object +
   one `OBJECT_FINALIZE`.
2. **Client** (1–2 PRs): `PendingUpload` fields + the resumable worker +
   error classification + progress UI; behind a flag, preferring
   `resumable_session_uri` when present, falling back to `signed_url`.
3. **Subscriber generation-dedup** (1 PR): independent hardening; lands the
   "exactly-once" guarantee even for legacy clients.
4. **Verify on a real long, weak-network upload**: confirm resume across a
   forced network drop, one `OBJECT_FINALIZE`, no stt-worker `submit race`,
   accurate progress bar. Then remove the single-PUT fallback in a later
   release once old clients age out.

## 11. Risks
- **Session URI as a bearer capability** — scope is one object, ~7d; acceptable
  (≈ current signed URL). Don't log it.
- **Memory** — must stream chunk byte-ranges from disk, never load the whole
  file. Enforce in code review + a test with a large fixture.
- **Clock/expiry** — treat `resumable_expires_at` as advisory; rely on GCS's
  `404/410` to detect a dead session and re-initiate.
- **Chunk size** — too small = many requests; too large = a drop wastes more.
  8 MiB default (multiple of 256 KiB, GCS requirement for non-final chunks).
