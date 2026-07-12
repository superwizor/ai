---
type: System Documentation
title: "21 — Session Status Propagation & Failure Semantics"
description: "Status: Implemented + deployed on feat/session-status-propagation (2026-05-30/31). Faza-4 full consolidation landed (2026-05-31): all four former per-topic n..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/21_SESSION_STATUS_PROPAGATION_AND_FAILURE_SEMANTICS.md
tags: []
timestamp: 2026-05-31T11:57:30+02:00
---

# 21 — Session Status Propagation & Failure Semantics

**Status:** Implemented + deployed on `feat/session-status-propagation`
(2026-05-30/31). **Faza-4 full consolidation landed (2026-05-31):** all four
former per-topic notification functions are collapsed into **one**
`notification-worker-on-status` consuming the unified `session.status_changed`
topic. `on-uploaded`/`on-transcribed` (pure mirrors) were retired first; then
`on-report` — which is *not* a pure mirror (it sends the "report ready" FCM
push + writes the inbox doc) — was folded into the `done` branch of
`ProcessSessionStatusChanged` (`handleReportReady`). `report.generated` (topic
+ DLQ + llm-worker publisher) is fully torn down; llm-worker now publishes
`session.status_changed("done")`. Only `on-status` + `on-deleted` remain.
**Branch:** `feat/session-status-propagation`

> **Implementation note (WS2A consolidation):** the literal
> `pipeline-dlq-reaper` Cloud Function (pull the DLQ reader subscriptions
> to fail sessions the instant retries exhaust, ~24h) was **not** built as
> a separate function. Its outcome — *FAILED + publish + release token on
> give-up* — is delivered by the **stt-watchdog time-backstop**
> (`reapStuckSessions`, ~26h) plus the **26h reservation TTL** (§3.7), plus
> **prompt token release on terminal STT failures** (`releaseBillingCredit`
> in handleSTTError / watchdog). Net effect is the same; the only
> difference is ~2h of detection latency for the rare retries-exhausted
> case, traded for far less machinery (no new CF/Eventarc, no billing
> client in notification-worker). llm-worker terminal content-filter
> failures release via the TTL (no billing client there).
**Supersedes the relevant parts of:** the `implementation_plan.md` audit of `SessionStatusScreen`
(the "mirror `failed` to Firestore" proposal) and ADR-IMPL-012's "Faza 4" gap in
[`08_FAZA_3_NOTIFICATIONS.md`](./08_FAZA_3_NOTIFICATIONS.md).
**Related:** [13 STT GCS Callback & Chunking](./13_STT_GCS_CALLBACK_AND_CHUNKING.md),
[15 Hybrid Eventarc Finalization](./15_HYBRID_EVENTARC_FINALIZATION.md),
[16 Billing Service Phase 3](./16_BILLING_SERVICE_PHASE_3.md).

---

## 1. TL;DR

Two user-visible bugs:

1. **Infinite spinner.** When a session fails (or gets stuck), the Flutter
   `SessionStatusScreen` spins forever, because the PG `FAILED` status is
   **never mirrored to Firestore** (`session_states/{id}`), which is the only
   thing the app subscribes to.
2. **Step 4 "muli" / sudden jumps.** `TRANSCRIBING` is also never mirrored, so
   the stepper sits on step 2 for the whole (long) transcription, then jumps
   straight to step 4.

The naive fix ("publish `FAILED` to Firestore whenever a worker writes
`FAILED`") is **actively dangerous** under the post‑Option‑F architecture,
where the **local audio is deleted right after the GCS PUT**. A *transient*
infra blip (Chirp 5xx, Vertex AI 500, a rate‑limit, a network hiccup) currently
self‑heals through Pub/Sub redelivery — but the worker still writes `FAILED` to
PG along the way. Mirroring that to the user would flash a **permanent‑looking
failure for a recording they can no longer re‑process**, even though the
pipeline was about to succeed on the next retry.

**The rule this design enforces:**

> **Transient / recoverable errors → keep retrying (up to ~24h). The user keeps
> seeing "in progress". Only if it is _still_ failing after the retry window —
> or the error is _definitively_ terminal — do we mark the session `FAILED` and
> tell the user.**

`FAILED` reaches the user from exactly **two authoritative sources**, never from
the transient retry path:
- **(T) Terminal classification** — the error will never succeed (bad codec,
  audio too long, invalid argument, content‑filter). Fail fast, notify now.
- **(G) Give‑up after ~24h** — retries genuinely exhausted (message lands in a
  DLQ) or a message was lost (time‑based backstop). Notify then.

---

## 2. Current state (verified from code, 2026-05-30)

### 2.1 The pipeline and where status is written

```
upload (Flutter, audio deleted after PUT)
  │  audio.objectFinalized  → ingestion-svc in-process subscriber
  ▼
stt-worker (submit to Chirp 3, GcsOutputConfig)         status: TRANSCRIBING (PG only)
  │  OBJECT_FINALIZE on transcripts-raw bucket
  ▼
stt-finalize  (merge Chirp output → transcripts)        status: MERGING → ...
  │  transcript.completed
  ▼
llm-worker (Vertex AI / Gemini → report)                status: ANALYZING → COMPLETED
  │  report.generated
  ▼
notification-worker-on-report                           Firestore: "done"

stt-watchdog (Cloud Scheduler, every 15 min)            rescues stuck Chirp ops
```

Firestore `session_states/{id}` is written by the **notification-worker** Cloud
Functions on these Pub/Sub events only:

| Event topic | Cloud Function | Firestore status |
|---|---|---|
| `audio.uploaded` | `notification-worker-on-uploaded` | `uploaded` |
| `transcript.completed` | `notification-worker-on-transcribed` | `analyzing` |
| `report.generated` | `notification-worker-on-report` | `done` |
| `session.deleted` | `notification-worker-on-deleted` | (doc wiped) |

**Gaps:** no mirror for `TRANSCRIBING` and no mirror for `FAILED`/`CANCELLED_BY_USER`.

### 2.2 How each stage handles errors today

| Stage | Transient error (5xx / Unavailable / deadline / 429) | Terminal error | Writes `FAILED` to PG? |
|---|---|---|---|
| **stt-worker** `handleSTTError` (`main.go:784`) | returns `err` → Pub/Sub retries | `isTerminalSTTError` true → ack, no retry | **Yes, unconditionally** (both branches) |
| **stt-finalize** (`objectFinalized.sub`) | NACK → retry | — | via `handleSTTError` |
| **llm-worker** (5 sites, `main.go:282…353`) | writes `FAILED`, returns `err` → Eventarc retries | **no distinction — everything retried** | **Yes, every error** |
| **stt-watchdog** `rescueOperation` (`watchdog.go:97`) | op still PENDING → waits ✅; **any `Poll` error** → `FAILED` ❌ | op error / per‑file error → `FAILED` ✅ | Yes on Poll error / op error |

Key code facts:
- `isTerminalSTTError` (`stt-worker/main.go:738`) already classifies STT errors
  correctly: `InvalidArgument / OutOfRange / NotFound / PermissionDenied /
  Unauthenticated` and Chirp file‑level errors are terminal; everything else
  (Internal/Unavailable/DeadlineExceeded/unknown) is retryable.
- `handleSTTError` (`main.go:784`) calls `updateSessionStatus(FAILED)` **before**
  checking terminality — so PG gets `FAILED` even on transient errors that are
  about to be retried.
- **llm-worker has no terminal/transient classifier at all** — every error path
  is `updateSessionStatus(FAILED); return fmt.Errorf(...)`.

### 2.3 The retry window is ~minutes, not 24h

Pub/Sub config (`infra/modules/pubsub/main.tf`, `infra/modules/cloud-functions/main.tf`):

| Subscription | `max_delivery_attempts` | backoff | retention | DLQ consumer? |
|---|---|---|---|---|
| `audio.objectFinalized.sub` (pull, stt-finalize) | **5** | 10s–600s | 7d | **none** (reader only) |
| `audio.uploaded` (Eventarc → stt-worker / notif) | Eventarc default (≈5) | Eventarc | 7d | **none** |
| `transcript.completed` (Eventarc → llm-worker / notif) | Eventarc default (≈5) | Eventarc | 7d | **none** |
| `report.generated` (Eventarc → notif) | Eventarc default (≈5) | Eventarc | 7d | **none** |

- The terraform comment claims a "24h retention window", but that is the
  *message retention* (7d here), not the **delivery‑attempt cap**. With
  `max_delivery_attempts = 5` and 10–600s backoff, retries exhaust in **minutes**.
- The DLQ topics exist and have `.reader` subscriptions, but **nothing consumes
  them** — they're inspection‑only.

**Consequence:** a Chirp/Vertex outage longer than ~5 attempts (minutes) →
message → DLQ → no consumer → session **stuck forever**: PG already `FAILED`
(from the unconditional write), Firestore stale at `uploaded`/`analyzing`, and
the local audio is gone. This is the production reality behind the infinite
spinner, e.g. session `f185a03b…` (a genuinely terminal "file too long", caught
by the watchdog, but still never mirrored).

### 2.4 The billing landmine

Reservation TTL is **4h** with a 5‑min expiry cron (see
[16 Billing Service Phase 3](./16_BILLING_SERVICE_PHASE_3.md)). If we retry a
session for up to 24h, the reservation **auto‑expires at 4h**; a retry that
finally succeeds at hour 6 would then fail to `CommitUsage` (reservation gone).
The TTL must be reconciled with the retry window.

---

## 3. Target design

### 3.1 Failure taxonomy (single source of truth)

```
classifyPipelineError(err) ∈ { TERMINAL, TRANSIENT }
```

| Class | Examples | Action |
|---|---|---|
| **TERMINAL** | bad codec, audio too long / too short, InvalidArgument, OutOfRange, NotFound, PermissionDenied/Unauthenticated, Chirp file‑level error, Vertex content‑filter block, invalid/!repairable schema | **Fail fast:** write `FAILED`, publish `session.status_changed(failed)`, release billing token, **ack** (no retry). |
| **TRANSIENT** | Chirp/Vertex 5xx (Internal/Unavailable), DeadlineExceeded, ResourceExhausted/429 from the *model API* (not billing quota), network/KMS/SQL hiccup, unknown | **Keep status in‑progress** (do **not** write `FAILED`, do **not** publish). NACK → Pub/Sub retries within the ~24h window. |

- STT: reuse `isTerminalSTTError`. **Fix:** move the `updateSessionStatus(FAILED)`
  in `handleSTTError` *inside* the terminal branch only.
- LLM: **add** an equivalent `isTerminalLLMError` (content‑filter / invalid
  argument / unrepairable schema = terminal; 5xx / quota / deadline = transient).
- Watchdog: **fix** `rescueOperation` so a transient `Poll` transport error
  (Unavailable/DeadlineExceeded/Internal) → "still pending, check next tick",
  **not** `FAILED`. Only a real operation/per‑file error is terminal.

> ⚠️ **Disambiguate two kinds of `ResourceExhausted`.** Billing
> `QUOTA_EXHAUSTED` (from `ReserveCredit` at upload time) is handled by the
> Flutter quota‑UX (doc work on `feat/tokens-exhausted`: park, no auto‑retry).
> Model‑API `RESOURCE_EXHAUSTED` (Vertex/Chirp rate‑limit mid‑pipeline) is
> **TRANSIENT** and must retry. They surface at different stages, so this is not
> ambiguous in practice, but the classifier comments must call it out.

### 3.2 `FAILED` reaches the user from only two sources

```
                 ┌─────────────── TERMINAL (T) ────────────────┐
worker/​watchdog ─┤  classify → FAILED + publish + release token │→ Firestore "failed"
                 └──────────────────────────────────────────────┘
                 ┌─────────────── GIVE-UP (G) ─────────────────┐
DLQ consumer ────┤  message dead after ~24h of retries          │→ Firestore "failed"
  + time backstop│  → FAILED + publish + release token          │
                 └──────────────────────────────────────────────┘
TRANSIENT in-flight ──→ status stays TRANSCRIBING/ANALYZING ──→ Firestore unchanged
```

### 3.3 Status mirror transport — unified `session.status_changed`

A single new topic carries the **currently‑unmirrored** transitions, consumed by
**one** Cloud Function (consolidates the per‑status proliferation; the existing 4
notification functions stay untouched):

- New topic `session.status_changed` (+ `.dlq` + Pub/Sub‑agent publisher IAM).
- `internal/statusevents.Publish(ctx, sessionID, status, therapistUID)` —
  best‑effort, structured‑logged, **never blocks** the PG write.
- New Cloud Function `notification-worker-on-status` →
  `ProcessSessionStatusChanged` → existing `firestore.Writer`.
- Publishers: `transcribing` (progress) + `failed` from the **(T)** and **(G)**
  sites only. `cancelled` from `clinical-svc.CancelSession`.

> We deliberately do **not** route `uploaded`/`analyzing`/`done` through the new
> topic — they already have working dedicated functions, and the Firestore rank
> guard (§3.4) makes any overlap idempotent anyway.

### 3.4 Firestore monotonic rank (writer.go)

```go
var sessionStatusRank = map[string]int{
    "":            0,
    "uploaded":    1,
    "transcribing":2,
    "analyzing":   3,
    "done":        4,
    "failed":      4,   // terminal — same tier as done
    "cancelled":   4,   // terminal
}
```
- Existing guard `newRank < currRank → skip` prevents monotonic regress.
- **Add a same‑rank terminal guard:** once a doc is `done` (or `cancelled`),
  a late `failed` (e.g. a DLQ‑retry message arriving after success) must **not**
  overwrite it. Rank changes are computed at write time from this map — no data
  migration needed (Firestore stores the status string, not the rank).

### 3.5 24h retry window

- Raise `max_delivery_attempts` to ~**144** (with `maximum_backoff = 600s`,
  144 × 10 min ≈ 24h) on `audio.objectFinalized.sub` and align the
  Eventarc‑managed subs (their dead_letter / retry config) for the
  llm‑worker and stt‑finalize stages. Retention already covers it (7d).
- This is the single most impactful change and is **infra‑only** — it gives
  transient errors the self‑heal window with no code change.

### 3.6 Give‑up (G): DLQ consumer + time backstop

- **DLQ consumer** (`pipeline-dlq-reaper`, new Cloud Function or folded into
  stt‑watchdog) subscribed to the pipeline DLQ topics. On a dead message:
  `FAILED` + `publish(failed)` + `ReleaseCredit(reason=PIPELINE_GIVEUP)`.
  Idempotent (no‑op if the session is already terminal).
- **Time backstop** in stt‑watchdog: a session in a non‑terminal state
  (`CREATED/TRANSCRIBING/MERGING/ANALYZING`) whose `status_updated_at` is older
  than **24–26h** with no terminal transcript/report → same give‑up action.
  Deadline is set **beyond** the retry window so it never preempts a live retry;
  it only catches genuinely lost messages (never published, never DLQ'd).

### 3.7 Billing reservation vs the 24h window

- Extend the reservation TTL to **≥24h** (+ widen the expiry cron horizon) so a
  long‑retried session can still `CommitUsage` on eventual success.
- Release on **(T)** terminal and **(G)** give‑up; commit on success. The token
  is genuinely "in use" for the lifetime of the (possibly retrying) session.

### 3.8 Flutter

- The `failed` path already works (stepper maps `failed`, `_onState` →
  `_scheduleFailureSheet`, queue dismisses on `failed`). With Firestore now
  mirroring `failed`, no correctness change is needed.
- `transcribing` mirror makes the stepper advance through step 3 instead of
  jumping 2 → 4.
- **Faza D (unified notification UI)** is included on this branch:
  `EuphireToast` + `EuphireActionSheet` variants + 22‑SnackBar migration + i18n.
- **Correction vs the original Faza C:** the client 30‑min "absolute timeout"
  must **only inform** ("Analiza trwa dłużej niż zwykle") — it must **not** mark
  the session failed. The backend now owns the authoritative 24h failure; a
  client that fails the session would contradict a pipeline that is still
  legitimately retrying.

---

## 4. Error scenarios & expected behavior

Legend: **FS** = Firestore `session_states` value the user effectively sees.

| # | Scenario | Class | PG status | FS / user sees | Outcome |
|---|---|---|---|---|---|
| 1 | Chirp 5xx / Unavailable, heals in 3 min | TRANSIENT | stays `TRANSCRIBING` | `transcribing` (in progress) | retry succeeds → `done`. No FAILED ever shown. |
| 2 | Vertex AI 500, heals in 20 min | TRANSIENT | stays `ANALYZING` | `analyzing` | retry succeeds → `done`. |
| 3 | Vertex 429 rate‑limit, heals in 2h | TRANSIENT | stays `ANALYZING` | `analyzing` | retries within 24h → `done`. Token still reserved (TTL ≥24h). |
| 4 | Bad codec / audio >20 min | TERMINAL | `FAILED` immediately | `failed` now | fail fast; failure sheet; token released. |
| 5 | Vertex content‑filter block | TERMINAL (new llm classifier) | `FAILED` immediately | `failed` now | fail fast. |
| 6 | Chirp outage lasts 30h (> window) | TRANSIENT → GIVE‑UP | `FAILED` at ~24h | `analyzing` until ~24h, then `failed` | retries exhaust → DLQ consumer → FAILED + notify + release. |
| 7 | Pub/Sub message → DLQ early (poison) | per class | depends | mirrors only on terminal/give‑up | DLQ consumer decides; transient‑looking poison still waits out the window. |
| 8 | Message lost entirely (never published / never DLQ'd) | — | non‑terminal forever | `analyzing` until ~25h, then `failed` | time backstop sweep → FAILED + notify + release. |
| 9 | Watchdog `Poll` hits transient Operations‑API outage | TRANSIENT (fixed) | unchanged | in progress | watchdog waits next tick (was: premature FAILED). |
| 10 | Happy path | — | `…→COMPLETED` | `uploaded→transcribing→analyzing→done` | stepper advances smoothly; success cascade. |
| 11 | Retry succeeds *after* a `failed` DLQ message is still in flight | — | `COMPLETED` then late `failed` arrives | `done` (kept) | same‑rank terminal guard prevents `done`→`failed` overwrite. |
| 12 | User cancels mid‑pipeline (quota‑UX bin) | — | `CANCELLED_BY_USER` | `cancelled` | CancelSession publishes; token released; hidden from kartoteka. |

### 4.1 Caveats / invariants to preserve

- **Idempotency everywhere.** Pub/Sub is at‑least‑once. Every consumer
  (status mirror, DLQ reaper, watchdog) must no‑op when the session is already
  terminal, and the Firestore writer's rank guard must hold under reordered
  delivery.
- **Never write `FAILED` on the transient branch.** This is the core invariant.
  A transient error must leave the session in its in‑progress status so (a) the
  user keeps seeing progress and (b) the time‑backstop / DLQ logic isn't tricked
  into a premature give‑up.
- **Token lifecycle:** reserve at upload → hold through retries → commit on
  success **or** release on terminal/give‑up. Exactly one of commit/release per
  session; both must be idempotent.
- **Reaper/backstop deadline > retry window.** If the backstop fired inside the
  24h retry window it would kill recoverable sessions — the exact bug we're
  fixing. Keep it at 24–26h, strictly beyond `max_delivery_attempts × max_backoff`.
- **`done` is sticky.** Once a session is `COMPLETED`/`done`, no later event may
  flip it to `failed` (or vice‑versa for `cancelled`).
- **Client never authoritatively fails a session.** The Flutter timeout informs
  only; the backend is the single source of truth for terminal state.
- **Quota `QUOTA_EXHAUSTED` ≠ model `RESOURCE_EXHAUSTED`.** The former parks the
  upload (no auto‑retry, user resends); the latter retries in‑pipeline.

---

## 5. Implementation workstreams

> Order: **0 + 1 together** (correctness + mirror are interdependent — the mirror
> must not publish on transient), then **2** (give‑up), then **3** (Flutter),
> verifying throughout (**4**). Single branch, small commits.

### Workstream 0 — Resilient retry & failure semantics
- **0A** Infra: `max_delivery_attempts ≈144` @ `max_backoff=600s` on
  `objectFinalized.sub`; align Eventarc subs + dead_letter for llm‑worker /
  stt‑finalize. (`infra/modules/pubsub/main.tf`, `cloud-functions/main.tf`)
- **0B** `handleSTTError`: write `FAILED` + publish only in the terminal branch.
- **0C** llm‑worker: add `isTerminalLLMError`; terminal → fail fast (FAILED +
  publish + release); transient → no FAILED, NACK.
- **0D** watchdog `rescueOperation`: transient `Poll` code → wait, not FAILED.
- **0E** billing: reservation TTL ≥24h + expiry‑cron horizon; release on
  terminal/give‑up.

### Workstream 1 — Status mirror (P0)
- **1A** `internal/statusevents.Publish` + topic `session.status_changed`
  (+DLQ +IAM).
- **1B** Publish `transcribing` (progress) + `failed` (from T sites only).
- **1C** `notification-worker-on-status` + `ProcessSessionStatusChanged` + CF
  (Eventarc) + writer ranks (`transcribing/failed/cancelled`) + done/cancelled
  guard.
- **1D** `clinical-svc.CancelSession` publishes `cancelled`.

### Workstream 2 — 24h give‑up
- **2A** `pipeline-dlq-reaper` consumer on the pipeline DLQs → FAILED + publish +
  release (idempotent).
- **2B** Time backstop in stt‑watchdog (24–26h non‑terminal sweep) → same action.

### Workstream 3 — Flutter (Faza D included)
- `EuphireToast`, `EuphireActionSheet` variants, 22‑SnackBar migration, i18n
  keys, `SessionStatusScreen` failure/stale sheets (**inform‑only** timeout).

### Workstream 4 — Verification
- Unit: terminal/transient classifiers (stt + llm); transient does **not**
  write/publish FAILED; watchdog transient‑Poll waits; writer rank + done‑guard;
  DLQ reaper marks FAILED + releases; reservation survives long retry then
  commits.
- Manual (staging): publish `session.status_changed(failed)` → Firestore →
  failure sheet; happy path mirrors `transcribing`; force a transient and watch
  it self‑heal without a FAILED flash; `gcloud pubsub topics list` shows the new
  topic; triage the stray `ssrsuperwizor` Cloud Function in FAILED state.
- e2e: `TestFullSession_HappyPath` regression.

---

## 6. Open questions / future

- **Full consolidation:** ✅ **DONE (2026-05-31).** `uploaded/transcribing/
  analyzing/done/failed/cancelled` all flow through `session.status_changed`
  into a single `notification-worker-on-status`. The four per‑event functions
  are retired — `on-uploaded`/`on-transcribed` as pure mirrors, and `on-report`
  by folding its report‑ready FCM push + inbox doc into the `done` branch
  (`handleReportReady`). `report.generated` topic/DLQ/publisher torn down.
  This closes the ADR‑IMPL‑012 Faza‑4 gap. Only `on-status` + `on-deleted`
  (RODO erase — a distinct action, not a status transition) remain.
- **Per‑stage retry budgets:** a 24h flat window is generous for STT but maybe
  long for LLM; could differentiate later if cost/latency dictates.
- **DLQ replay tooling:** an operator command to re‑inject a DLQ'd message after
  a fixed infra incident (vs. waiting for the give‑up to fail it).

---

## 7. Decision log

| Date | Decision | Rationale |
|---|---|---|
| 2026-05-30 | Transient errors retry up to ~24h, only then FAIL + notify | Post‑Option‑F the local audio is gone; a premature FAILED on a self‑healing blip permanently loses recoverable work. |
| 2026-05-30 | Unified `session.status_changed` topic + one function | Stops per‑status topic/function proliferation; ADR‑IMPL‑012 Faza 4 direction. |
| 2026-05-30 | Give‑up = DLQ consumer + 24–26h time backstop | Precise (DLQ) + resilient to lost messages (sweep). |
| 2026-05-31 | Faza‑4 full consolidation: fold `on-report` into `on-status` `done` branch; retire `report.generated` | `ProcessReportGenerated` only logged `report_id`; the FCM push + inbox both key off `session_id`, so the unified event carries everything. One function, one topic, one idempotency story — the report‑ready push lives in `handleReportReady`, called when `status==done`. |
| 2026-05-30 | Terminal errors fail fast | No point making a user wait 24h for a bad‑codec error they could re‑record now. |
| 2026-05-30 | Extend reservation TTL to ≥24h | Reconcile billing with the retry window so a late success can commit. |
| 2026-05-30 | Client timeout informs only, never fails | Backend is the single source of truth for terminal state. |
