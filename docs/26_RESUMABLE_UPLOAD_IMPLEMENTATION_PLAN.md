# 26. Implementation Plan — Resumable / Chunked Audio Upload

**Status:** Draft for review.
**Supersedes/extends:** `25_RESUMABLE_UPLOAD_DESIGN.md` (the vetted design — read it first; this doc is the actionable plan reconciled with the *current* code).
**Owner:** TBD.
**Motivating bug:** Martin's sessions "Gestalt 8 & 9" stuck in `PENDING_UPLOAD` ("Oczekiwanie na audio…") — see analysis below.

---

## 1. The bug (user-facing)

Two ~130-min recordings created sessions server-side but their audio **never reached GCS**:
- `sessions.status = PENDING_UPLOAD`, `audio_uploads.status = PENDING`, `upload_completed_at = NULL`, `file_size_bytes = NULL`, **no GCS object**.
- The recordings are safe on the device but stranded; the UI shows a spinner forever.

**Root cause:** the client does a **single whole-file HTTP PUT** of a ~62 MB OGG to the signed URL (`upload_io_grpc.dart::putBytes` → `_http.put(signedUrl, body: bytes)`). On cellular, any network drop restarts the PUT from byte 0; on a weak link it loops refreshing signed URLs and never completes. There is **no resume and no progress persistence**.

**Fix:** upload the object in **resumable byte-range chunks** (GCS resumable protocol) with the acked offset persisted across app-kill — so a 130-min recording reliably lands over flaky networks and the user sees real progress.

> Note: this is *upload-transport* chunking. It is distinct from (a) the on-device **AES-256-GCM 1 MB encryption chunks** (durability) and (b) the server-side **STT chunker** (`chunker.go`, ≤20-min Chirp splits). Both are unchanged — the server still receives **one object per session**.

---

## 2. Current state (what exists today)

| Layer | Today |
|---|---|
| Client transport | Single `http.put(signedUrl, body: wholeFileBytes)` — whole file in memory, restart-from-0 on failure (`upload_io_grpc.dart` `putBytes`). |
| On-device storage | Recording stored as AES-256-GCM `chunk_*.enc` (1 MB) in `sessions/<id>/`; `decryptToTempFile` reassembles ONE plaintext temp file for the PUT (`secure_audio_storage_service.dart`). |
| Signed URL | V4 **PUT** signed URL only, TTL 30 min → 4 h by size (`signer.go` `GenerateUploadURL` / `signedURLTTLFor`). No resumable. |
| Proto | `CreateAudioUploadResponse{ upload_id, signed_url, signed_url_expires_at, object_path, required_headers, session_id }`. No resumable fields. |
| Queue | `PendingUpload` phases `…→created→uploaded→completed`; no byte-offset/progress persistence. |
| Server finalize | GCS `OBJECT_FINALIZE` → ingestion subscriber → probe/convert/chunk(STT)/flip status (Option F). One object per session expected. |

---

## 3. Target design (GCS resumable upload)

Three-step protocol (doc 25 §2–3):
1. **Initiate (server):** `POST …/upload/storage/v1/b/<bucket>/o?uploadType=resumable&name=<obj>` with OAuth + `X-Upload-Content-Type/Length` + `ifGenerationMatch=0` → GCS returns `Location: <sessionUri>` (~7-day life).
2. **Upload chunks (client):** `PUT <sessionUri>` with `Content-Range: bytes a-b/total`, body = 8 MiB range read from disk → `308 Resume Incomplete` between chunks; `200/201` on the **final** chunk (object finalizes **exactly once**).
3. **Resume:** `PUT <sessionUri>` with `Content-Range: bytes */total`, empty body → `308 Range: bytes=0-K` ⇒ next byte = K+1; send only the remainder.

Object commits only on the final chunk ⇒ exactly one `OBJECT_FINALIZE` (also fixes the duplicate-finalize storm, doc 25 §1/§7).

---

## 4. Work breakdown (PR sequence)

### PR 1 — Server: resumable session (ship dark, backward-compatible)
**ingestion-svc + proto + migration**
- [ ] **Migration** `audio_uploads`: `+ resumable_session_uri TEXT`, `+ resumable_session_expires_at TIMESTAMPTZ` (nullable). Add sqlc query to read/write them.
- [ ] **`signer.go`**: `StartResumableSession(ctx, objectPath, contentType string, estSize int64) (uri string, expires time.Time, err error)` — POST to the resumable endpoint, `ifGenerationMatch=0`, set `X-Upload-Content-Type`, optional `X-Upload-Content-Length`; parse `Location`.
  - **Auth gotcha — don't hand-roll OAuth.** The standard `storage.Client` can't hand you a resumable *session URI*, so this is a **raw HTTP POST** to `https://storage.googleapis.com/upload/storage/v1/b/<bucket>/o?uploadType=resumable&name=<obj>`. That request MUST go through a client that attaches the Cloud Run service-account token. Build one with `google.golang.org/api/transport/http` (once, at startup — not per request):
    ```go
    import (
        "google.golang.org/api/option"
        httptransport "google.golang.org/api/transport/http"
    )
    client, _, err := httptransport.NewClient(ctx,
        option.WithScopes("https://www.googleapis.com/auth/devstorage.read_write"))
    ```
    The SA already has `storage.objectAdmin` on the bucket (`service-accounts.tf` ingestion bindings), so the `devstorage.read_write` scope is sufficient. Never log the returned session URI (bearer capability).
- [ ] **`CreateAudioUpload` handler**: after the existing reserve + row create/lookup, if the row has a non-expired `resumable_session_uri` reuse it; else `StartResumableSession` and persist URI+expiry. Return both legacy `signed_url` (unchanged) **and** the new fields.
- [ ] **proto** `CreateAudioUploadResponse +=`:
  ```proto
  string resumable_session_uri = 7;
  google.protobuf.Timestamp resumable_expires_at = 8;
  int64  recommended_chunk_size_bytes = 9;   // e.g. 8 MiB (multiple of 256 KiB)
  ```
  (additive — old clients ignore them). Regen Go (CI `buf generate`) + commit `gen/ts`.
- [ ] **GCS bucket CORS — web future-proofing (optional for the mobile rollout; required before the web path).** In `infra/modules/audio-storage/main.tf` the `audio_uploads` `cors{}` currently exposes only `["Content-Type", "x-goog-content-length-range"]`. The mobile app (`dart:io HttpClient`) ignores CORS, but a *browser* doing resumable chunks must be allowed to **send** `Content-Range`/`x-goog-resumable` and **read** `Range`/`Location` off the `308 Resume Incomplete`. In GCS, `response_header` drives BOTH `Access-Control-Allow-Headers` and `Access-Control-Expose-Headers`, so extend it:
  ```hcl
  cors {
    # NB: also tighten origin "*" → the real web origins (see docs/agents/11).
    origin          = [...]
    method          = ["PUT", "OPTIONS"]   # server initiates; browser only PUTs chunks
    response_header = [
      "Content-Type",
      "x-goog-content-length-range",
      "Content-Range",     # client → GCS (chunk range)
      "Range",             # read from 308 Resume Incomplete
      "Location",          # read the resumable session URI
      "x-goog-resumable",
    ]
    max_age_seconds = 3600
  }
  ```
  Do it in PR1 (cheap, no mobile impact) or defer to the web PR — but don't forget it, or the eventual web resumable path silently 403s on preflight.
- [ ] **Go e2e** (`tests/e2e`): initiate → PUT 2 chunks (expect 308 then 200) → force a resume query mid-way → assert single object + single finalize.
- **Risk:** none to existing clients (additive). Deployable independently of the client.

### PR 2 — Client: resumable worker (behind a flag)
**Flutter**
- [ ] **`PendingUpload +=`** `String? resumableSessionUri`, `DateTime? resumableExpiresAt`, `int bytesUploaded` (persisted), `int chunkSizeBytes`; update `copyWith` + JSON (`toJson`/`fromJson`) + the Hive round-trip.
- [ ] **`createUpload`** maps the new response fields onto the row.
- [ ] **Resumable `putBytes`** (new code path, prefer when `resumableSessionUri != null`):
  - `ensureSession()` — if URI null/expired → re-`CreateAudioUpload` (idempotency key returns same or fresh session).
  - `resume()` — `PUT` `Content-Range: bytes */total`, empty body; parse `308 Range` → set `bytesUploaded`.
  - `uploadLoop()` — while `bytesUploaded < total`: read `[bytesUploaded, +chunkSize)` from disk via `RandomAccessFile` (**stream, do not load whole file**), `PUT` with `Content-Range`; on `308` advance + **persist** `bytesUploaded` + `onProgress`; on `200/201` done; on `5xx`/network backoff→`resume()`→retry.
  - For `encryptedChunks`: decrypt to temp file first (as today), stream ranges from it, delete temp in `finally`.
- [ ] **Error classification** (doc 25 §5.3): `308`=progress, `200/201`=done, `5xx/network`=retryable→resume, `404/410/403`=session-gone→re-create+reset offset, `400`=resume to re-sync.
- [ ] **Progress UI**: "Wgrywanie" pill shows `bytesUploaded/total` %.
- [ ] **Fallback**: if no `resumableSessionUri`, use the legacy single PUT (keeps working during rollout).
- [ ] **Tests**: worker unit tests — 308 loop advances offset, resume after simulated 404, app-kill resume from persisted offset, range-header parsing.

### PR 3 — Server: finalize dedup (independent hardening)
- [ ] Ingestion subscriber dedups `OBJECT_FINALIZE` by object **generation** (store processed generation on `audio_uploads`; ack stale/duplicate generations without republishing). Defense-in-depth even with resumable.
- **Why this is still needed with resumable:** the resumable protocol guarantees the object is *created* exactly once (only the final chunk finalizes), but **GCS→Pub/Sub event delivery is "at least once"** — the same `OBJECT_FINALIZE` can be delivered multiple times. Tracking the object `generation` (monotonic per object version) in `audio_uploads` is the robust idempotency guarantee: process a generation once, ack any repeat. This makes the pipeline correct regardless of redelivery, and also covers the legacy single-PUT path during rollout.

### PR 4 — Verify + clean up
- [ ] Real-device test: long recording over a **throttled/dropping** network; confirm resume across drops, **one** finalize, accurate progress bar, app-kill/relaunch resume.
- [ ] After old clients age out: remove the single-PUT fallback (client) and eventually the legacy `signed_url` (keep for web for now).

---

## 5. Key decisions / parameters
- **Chunk size:** 8 MiB default (must be a multiple of 256 KiB per GCS). Server sends `recommended_chunk_size_bytes`; client may clamp.
- **Memory:** MUST stream chunk ranges from disk (`RandomAccessFile.setPosition/read`). Reviewer gate + a large-fixture test.
- **Expiry:** treat `resumable_expires_at` as advisory; rely on GCS `404/410` to detect a dead session and re-initiate.
- **Security:** the session URI is a bearer capability scoped to one object (~7 d) — never log it (mirror the existing `_redact` for signed URLs).
- **Encryption interplay:** unchanged — decrypt-to-temp then stream. (A future optimization could stream-decrypt per range, but not in scope.)

## 6. Deltas from doc 25 (it predates recent work)
- `session_id` is already returned at create time (Option E) — keep it; the status screen can switch to server listeners once it lands.
- The reservation TTL is now **26h** (`DefaultReservationTTL`), and a separate branch adds **reserve-by-duration**; both are compatible and independent.
- The **deferred web upload** path (`docs/agents/12`) should adopt the same resumable flow when it's built (browser `fetch` supports `Content-Range` PUTs too).

## 7. Effort & risk
- **Size:** medium-large, cross-stack (proto + ingestion + migration + Flutter worker + UI). **Architectural risk: low** — additive, server expectations unchanged, design already vetted.
- **Sequenceable:** PR1 ships dark with zero client impact; PR2 behind a flag; PR3 independent.

## 8. Immediate mitigations (before this ships)
- **Recover Gestalt 8 & 9 now:** their `audio_uploads` rows + signed URLs are valid until **06-07** and the recordings are on Martin's device — open the app on **Wi-Fi**, foreground + charged, let the queue drain; if parked, "Wyślij ponownie".
- **UX gap (file alongside this work):** a stalled large upload shows only "Oczekiwanie na audio…" with no progress or Wi-Fi guidance. Add a clearer pending/progress state and consider **Wi-Fi-preferred** for large uploads. This is the user-visible half of the bug and is independent of the resumable transport.

---

## 9. Acceptance criteria
- A 130-min recording uploads to completion over a network that drops mid-transfer (resumes, doesn't restart).
- Exactly one GCS object + one `OBJECT_FINALIZE` per session.
- Upload survives app-kill and resumes from the last acked byte.
- "Wgrywanie" shows real progress.
- Old clients (single PUT) keep working throughout rollout.
