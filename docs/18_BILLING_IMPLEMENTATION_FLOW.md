---
type: System Documentation
title: "18. Billing — End-to-End Implementation Flow"
description: "Version: 2.0 (2026-05-27, post Phase C refactor) Status: Current live behavior on staging. Snapshot of the deployed billing pipeline. Related: 16BILLINGSERVI..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/18_BILLING_IMPLEMENTATION_FLOW.md
tags: [billing]
timestamp: 2026-06-04T23:32:52+02:00
---

# 18. Billing — End-to-End Implementation Flow

**Version:** 2.0 (2026-05-27, post Phase C refactor)
**Status:** Current live behavior on staging. Snapshot of the deployed billing pipeline.
**Related:** `17_BILLING_SERVICE_PHASE_3.md` (canonical design — note that the Firestore-mirror / outbox-poller sections of §16 are superseded; see §5 below), `agents/03_billing-svc.md` (service-level reference), `agents/00_GLOBAL_CONTEXT.md`.

This document maps the production-grade flow as it actually runs in staging — every component, every gRPC hop — for a single session from app launch through quota enforcement, STT, LLM, and quota-state propagation. Use it when debugging a billing bug or onboarding to the system.

For the *why* (design rationale, ADRs, threshold tuning), read §16 first — but always cross-check against §5 here since Phase C significantly simplified the propagation layer.

---

## What changed in v2.0 (Phase C refactor, branch `feat/billing-svc-refactor`)

The original Phase 3 design (v1.0) fanned billing-state changes out via:

- billing-svc writes to `outbox_events` table inside the same tx as the counter mutation
- in-process poller goroutine publishes to Pub/Sub topic `billing.outbox`
- Cloud Function `notification-worker-on-billing` consumes → writes `organization_quota/{org_id}` Firestore doc → optional FCM push
- Flutter subscribes to the Firestore mirror live and updates UI from it

Phase C removed all four hops. Quota state now propagates **only** via direct RPCs:

- Flutter cold-start: `clinical-svc.GetMyBillingState()` returns the canonical `billing.v1.Subscription` proto
- Every `ReserveCredit` and `CommitUsage` response embeds `state_after` (a fully-populated `Subscription` snapshot) — Flutter applies that to its in-memory `BillingQuotaCache` inline
- No Pub/Sub topic, no Cloud Function, no Firestore mirror, no outbox table

The notification-svc still owns FCM push for session lifecycle events (uploaded / transcribed / report ready / session deleted). It just no longer participates in billing fan-out.

Migration `000034_drop_outbox_events.up.sql` dropped the table; `terragrunt apply staging` destroyed `billing.outbox` topic + DLQ + IAM + the `notification-worker-on-billing` Cloud Function.

Removed packages (visible in `git log feat/billing-svc-refactor`):
- `services/billing-svc/internal/outboxpoller/`
- `services/billing-svc/internal/adapters/pubsub/`
- `services/billing-svc/internal/domain/outbox/`
- `services/billing-svc/internal/adapters/postgres/queries/outbox.sql`
- `services/notification-svc/cmd/worker/main.go`: `ProcessBillingEvent` CloudEvent handler + `BillingEventPayload` + `localizeBillingEvent` + `computeWarningLevel`
- `services/notification-svc/internal/adapters/firestore/writer.go`: `OrganizationQuota` struct + `WriteOrganizationQuota`
- `lib/services/billing_quota_listener.dart` (Flutter)

---

## 0. Boot state — data model

```
organizations (T1.. T222 — bootstrapped by /tmp/dbq/seed_orgs.go)
   ├── 1:1 → subscriptions (plan_tier: SOLO|PRO|CLINIC|TRIAL,
   │                         plan_cycle: MONTHLY|ANNUAL,
   │                         status: ACTIVE|PAST_DUE|TRIALING)
   │                            │
   │                            └─ 1:1 → usage_counters (per active period)
   │                                       ├── tokens_limit  (from plan: 20 / 100 / 500; Trial = 3)
   │                                       ├── tokens_used   (consumed)
   │                                       ├── tokens_reserved (held but not yet consumed)
   │                                       ├── period_start  (e.g. 2026-05-01)
   │                                       └── period_end    (e.g. 2026-06-01)
   │
   └── 1:N → users (therapists)

pending_reservations     — UNIQUE on session_id; status ACTIVE|EXPIRED|COMMITTED|RELEASED; TTL 4h
usage_events             — UNIQUE on session_id; the "commit" record (tokens_consumed, duration_seconds)
subscription_plans       — catalog (SOLO/PRO/CLINIC × MONTHLY/ANNUAL + Trial)
payment_events           — payment gateway audit (Stripe events, currently stubbed)
```

**Gone in v2.0:** `outbox_events` table (migration 000034). The `OutboxStatus` enum from migration 000002 is an orphan now — left in place because no other table referenced it.

Token semantics (ADR-DM-017): `1 token = up to 75 min audio (hard boundary, no grace)` →
`tokens = max(1, ceil(duration_s / 4500))`.

`remaining = limit − used − reserved`. Warning thresholds for UI rendering live **client-side** now (`flutter-app/superwizor/lib/services/billing_quota_state.dart::QuotaState.computeLevel`): warning at `remaining ≤ 5`, critical at `remaining ≤ 1`, exhausted at `remaining == 0`. No backend-side edge-event emission.

Trial provisioning (commit `0a25ac7`): `identity-svc.CreateUser` for a THERAPIST role wraps its writes in a tx that also INSERTs an `organizations` row ("`<First> <Last>` Org", type SOLO), points `users.organization_id` at it, INSERTs a TRIAL `subscriptions` row (status TRIALING, period_end NOW+100yr, billing_source MANUAL), and INSERTs the matching `usage_counters` row with `tokens_limit=3` from the TRIAL plan. So every new therapist starts with a usable 3-token quota out of the box.

---

## 1. App startup — Flutter pulls from clinical-svc

```
Flutter app launches
   │
   ├─ currentUserProvider  → identity-svc.GetUser
   │
   └─ billingQuotaProvider.build()
       │
       └─ BillingQuotaCache.refresh()
           │
           └─ clinical-svc.GetMyBillingState(Empty)
               │
               ├─ extract user_id from auth ctx
               ├─ GetUserOrganizationID(user_id)
               └─ billing-svc.GetSubscription(org_id)
                       │
                       └─ returns billing.v1.Subscription:
                            { plan_tier, plan_cycle, status,
                              tokens_per_period, tokens_used_this_period,
                              tokens_reserved_this_period, tokens_remaining,
                              current_period_start, current_period_end, … }
```

The proto comes back to Flutter; `BillingQuotaCache._fromProto` maps it to a `QuotaState` and stuffs it in a `ValueNotifier<QuotaState?>`. `BillingQuotaNotifier` (Riverpod) listens to that notifier and re-emits as `AsyncData<QuotaState?>` so existing consumers keep their API.

Per user direction: **no refresh on app resume**. Cold start is the only automatic refresh path. The cache is also refreshed after every successful `ReserveCredit` (via the `state_after` field — see §2d).

UI consumers (unchanged):
- `lib/widgets/quota_warning_banner.dart` — sticky banner above the "Aktywne kartoteki" list on `home_screen.dart`
- `lib/widgets/pending_quota_sessions_widget.dart` — patient-scoped, on `client_details_screen.dart`
- `lib/widgets/quota_exhausted_dialog.dart` — fired when `ReserveCredit` returns `ResourceExhausted`
- `lib/screens/subscription_plan_screen.dart` — full quota view (moved into the Settings menu in `778efd8`)

If `GetMyBillingState` fails (network / no billing wiring) the cache stays `null` and the UI hides quota chrome — same behaviour as the old empty-Firestore-doc case.

---

## 2. Record + Submit — quota gate at upload time

### 2a. Flutter side

```
RecordingScreen → user stops recording
   │
   └─ UploadQueueRunner.enqueueAndKick()  (lib/uploads/upload_queue_runner.dart)
       ↓
   PendingUpload row in local Hive, phase=pending
       ↓
   For each due tick:
     ingestionClient.CreateAudioUpload(
       therapist_id, patient_file_id, content_type,
       estimated_size_bytes, idempotency_key=<uuid-v4 per attempt>,
       client_platform, client_app_version
     )
```

Cold-start backoff reset (commit `93e96d5`): when the runner starts (app launch or therapist switch), it pulls any non-terminal row's `nextAttemptAt` back to *now* before the initial tick — so a row parked on `QUOTA_EXHAUSTED` from a previous session gets one fresh attempt immediately instead of waiting for the 30-min backoff window to elapse.

Quota-recovery listener (commit `eee4ef2`): mid-session, when `BillingQuotaCache` fires a `tokensRemaining 0 → >0` transition (admin topped up tokens), `upload_queue_provider` calls the same reset + `runner.kick()` so the parked row retries without an app restart.

### 2b. ingestion-svc gRPC handler

`services/ingestion-svc/internal/adapters/grpc/server.go::CreateAudioUpload`

```
1. Parse therapist_id, patient_file_id, idempotency_key (required)

2. Idempotency pre-check
   GetAudioUploadByIdempotency(idempotency_key, therapist_id)
     │
     ├─ HIT  → cachedAudioUploadResponse(existing)
     │           │
     │           ├─ reserveCreditOrBlock(session_id, therapist_id)   ← commit 7d876fc
     │           │   Closes the bypass where Flutter retries of an
     │           │   over-quota upload short-circuited around the
     │           │   reserve check.
     │           │
     │           └─ GenerateSignedURL → return CreateAudioUploadResponse
     │
     └─ MISS → continue to step 3

3. Begin Postgres tx
   3a. GetNextSessionNumber(patient_file)
   3b. GetSessionDefaultsForPatientFile(patient_file)
   3c. CreateSessionPendingUpload(...)              → session row (status=PENDING_UPLOAD)
   3d. CreateAudioUpload(idempotency_key)           → audio_upload row
       │
       └─ on unique-violation (ux_audio_uploads_idempotency):
           rollback + GetAudioUploadByIdempotency → cachedAudioUploadResponse
   3e. SetSessionAudioUploadID(session.id, upload.id)
   3f. tx.Commit                                    ← session + audio_upload now persisted

4. reserveCreditOrBlock(session_id, therapist_id)
   │
   ├─ GetUserOrganizationID  (PG users table)
   ├─ billing-svc.ReserveCredit gRPC (Cloud Run, OIDC service-to-service)
   │
   └─ Error taxonomy:
       ResourceExhausted (QUOTA_EXHAUSTED)        → return ResourceExhausted   ✋ HARD BLOCK
       FailedPrecondition (PAST_DUE / INACTIVE)   → return FailedPrecondition  ✋ HARD BLOCK
       Unavailable / Internal / network           → log, return nil (fail-soft)

5. GenerateUploadURL  (V4 signed URL, 30-min TTL)
6. Return CreateAudioUploadResponse
```

### 2c. billing-svc.ReserveCredit

`services/billing-svc/internal/adapters/grpc/server.go::ReserveCredit`

```
1. GetReservationBySession(session_id)
   └─ HIT → return existing reservation + state_after  (idempotent on session_id)

2. GetActiveSubscriptionByOrg(org_id)
   ├─ NoRows               → return FailedPrecondition: SUBSCRIPTION_INACTIVE
   └─ status=PAST_DUE      → return FailedPrecondition: SUBSCRIPTION_PAST_DUE

3. Begin tx
   3a. AcquireSubscriptionLock(sub_id)              ← pg_advisory_xact_lock
   3b. LockActiveCounter(sub_id) FOR UPDATE
       └─ NoRows           → return FailedPrecondition: QUOTA_COUNTER_MISSING

   3c. remaining = limit − used − reserved
       if remaining < estimated_tokens (default 1):
           return ResourceExhausted: QUOTA_EXHAUSTED

   3d. CreateReservation(session_id, sub_id, org_id, tokens, expires_at = NOW+4h)
       └─ unique-violation race → rollback + refetch existing
   3e. AddReservedTokens(counter_id, +tokens)

   3f. tx.Commit
4. Build Subscription proto (buildSubscriptionProto helper)
   with post-mutation counters → embed as state_after
5. Return Reservation{reservation_id, session_id, tokens, expires_at, state_after}
```

**Note:** No `AppendOutboxEvent`. No Pub/Sub publish. The `state_after` field is the only out-of-tx propagation — it's part of the gRPC response and carried back to Flutter (via ingestion-svc which proxies the relevant bits).

### 2d. Flutter post-response

```
CreateAudioUploadResponse received
   ├─ OK                       → PUT audio to signed URL, advance phase to "created"
   │                              UploadQueueRunner.onReservationCreated(row) fires:
   │                                │
   │                                ├─ BillingQuotaCache.applyOptimisticReservation(+1)
   │                                │     (instant local decrement so UI updates between RPCs)
   │                                │
   │                                └─ BillingQuotaCache.refresh()
   │                                      → clinical-svc.GetMyBillingState
   │                                      → authoritative server snapshot lands
   │
   └─ ResourceExhausted        → show QuotaExhaustedDialog
       FailedPrecondition       (no PUT happens; orphan session+upload rows
                                 expire via audio_uploads.expires_at TTL;
                                 row stays in queue, retries with backoff —
                                 cold-start reset + quota-recovery listener
                                 cover the unstuck path)
```

The reservation proto carries the new `state_after`, but the wire path Flutter → ingestion-svc → billing-svc means Flutter sees only the `CreateAudioUploadResponse`. The cache refresh is what brings the new state to the UI — a second RPC, but to clinical-svc.GetMyBillingState which returns the same `Subscription` shape we got from the cold-start path.

---

## 3. STT pipeline — async path

### 3a. GCS finalize on raw audio bucket

```
Flutter PUTs to gs://superwizor-ai-25ecd-audio-uploads/<therapist>/<session>/<ts>.flac
   ↓
Eventarc OBJECT_FINALIZE → audio.uploaded Pub/Sub topic
   ↓
ingestion-svc subscriber (background pull, lives in same gRPC service)
   ├─ ffprobe → duration_seconds
   ├─ UpdateSessionDuration(session_id, duration_seconds)    ← used by CommitUsage later
   └─ publish stt.audio_ready  → stt-worker (Cloud Function)
```

### 3b. stt-worker (entry: `ProcessUploadedAudio`)

```
services/ai-pipeline-svc/cmd/stt-worker/main.go
   ├─ chunker.ChunkByPauses → []chunker.Chunk
   ├─ submit Chirp BatchRecognize with GcsOutputConfig.Uri=gs://transcripts-raw/...
   └─ exit (Chirp writes JSON to GCS asynchronously)
```

### 3c. stt-finalize (entry: `ProcessTranscriptObject`)

```
Triggered by OBJECT_FINALIZE on transcripts-raw bucket
services/ai-pipeline-svc/cmd/stt-worker/finalize.go::ProcessTranscriptObject
   │
   ├─ loadChunkResults — read+merge per-chunk Chirp output
   ├─ persistTranscript:
   │    ├─ JSON-encode []BlobLine{chunk_idx, text, start_ms, end_ms,
   │    │                         word_count, confidence,
   │    │                         speaker_tag?, speaker_label?}
   │    ├─ KMS-encrypt → INSERT transcripts (transcript_ciphertext)
   │    └─ INSERT transcript_segments (one row per chunk, encrypted text)
   ├─ updateSessionStatus(session_id, "ANALYZING")
   │
   ├─ commitBillingUsageAsync(session_id)                    ← goroutine
   │    │   (services/ai-pipeline-svc/cmd/stt-worker/main.go::commitBillingUsageAsync)
   │    │   BILLING_SVC_URL must be set on stt-finalize     ← d15f6e7 fix
   │    │
   │    ├─ Postgres lookup: duration_seconds, therapist_id, organization_id
   │    └─ billing-svc.CommitUsage(session_id, org_id, therapist_id,
   │                               duration_seconds, usage_type="session_analysis",
   │                               idempotency_key="stt-commit-<session_id>")
   │
   └─ publishTranscriptCompleted(session_id, transcript_id)  → llm-worker
```

### 3d. billing-svc.CommitUsage

`services/billing-svc/internal/adapters/grpc/server.go::CommitUsage`

```
1. GetUsageEventBySession(session_id)
   └─ HIT  → return UsageCommit + state_after (idempotent)   ← session_id UNIQUE constraint

2. Begin tx + AcquireSubscriptionLock + LockActiveCounter

3. tokens_to_charge = tokens.Calculate(duration_seconds)
                    = max(1, ceil(duration / 4500))   // 1 token = ≤75min, no grace

4. CreateUsageEvent(session_id, sub_id, org_id, tokens, duration_seconds, usage_type)

5. GetReservationBySession(session_id)
   ├─ ACTIVE → reserved_to_release = reservation.tokens_reserved
   │           MarkReservationCommitted(session_id)
   └─ none    → reserved_to_release = 0
                ↑ KNOWN GAP: no quota check at commit. Counter can go over
                  if upstream allowed an upload past the gate. Defense in
                  depth pending — see §11.

6. CommitTokens(counter_id, +tokens_to_charge, -reserved_to_release)

7. tx.Commit
8. Build Subscription proto with post-mutation counters → embed as state_after
9. Return UsageCommit{tokens_consumed, remaining_tokens, limit_tokens, state_after}
```

**Note:** No outbox emission, no edge-threshold computation, no Pub/Sub. The single side-effect on the wire is `state_after` in the response. stt-finalize doesn't propagate that anywhere — but its commit triggers the natural client refresh path via the next `ReserveCredit` (or app restart). For users sitting on the QuotaWarningBanner during analysis, the banner staleness window is "until next reservation or app cold-start". Considered acceptable per the Phase C plan ("minimise database hits / no need to refresh on app resume — only restart").

---

## 4. LLM analysis — role assignment + blob rebuild

(Unchanged from v1.0. Not billing-specific; included here for completeness of the session lifecycle.)

```
llm-worker (entry: ProcessTranscript) consumes transcript.completed
   │
   ├─ loadTranscriptBlob(transcript_id)             ← 1 KMS decrypt
   ├─ generateReport (Vertex AI Gemini)
   ├─ persistReport (encrypted)
   │
   ├─ generateAndSaveSpeakerLabels:
   │     │
   │     ├─ Map SpeakerGroups → chunk_idx → speaker_tag → role label (rolelabels.Generate)
   │     ├─ tx:
   │     │   ├─ UPDATE transcript_segments SET speaker_tag, speaker_label per chunk
   │     │   ├─ UPDATE sessions.speaker_label_mapping = {"1":"Terapeuta","2":"Pacjent",…}
   │     │   ├─ rebuildBlobWithRoles(transcript_id, chunkToTag, tagToLabel)     ← commit fe92d48
   │     │   │   ├─ SELECT transcript_ciphertext FOR UPDATE
   │     │   │   ├─ 1 KMS decrypt
   │     │   │   ├─ apply chunk_idx → speaker_tag / speaker_label per blob line
   │     │   │   ├─ 1 KMS encrypt
   │     │   │   └─ UPDATE transcripts SET transcript_ciphertext + blob_rebuilt_at
   │     │   └─ tx.Commit                                                       ← 2 KMS calls total
   │
   ├─ updateSessionStatus(session_id, "COMPLETED")
   └─ publishReportGenerated(session_id, report_id)
```

After this step the blob carries `speaker_label != ""` per line — the marker that lets clinical-svc safely use the fast canonical-read path (`tryCanonicalBlobSegments` in `services/clinical-svc/internal/adapters/grpc/session.go`).

---

## 5. Billing-state propagation (Phase C — current)

```
WHERE STATE CAN CHANGE                  HOW FLUTTER FINDS OUT

Reservation commit (§2c)                state_after on ReserveCredit response
                                         → ingestion-svc forwards CreateAudioUpload OK to Flutter
                                         → UploadQueueRunner.onReservationCreated() fires
                                         → BillingQuotaCache.applyOptimisticReservation(+1)
                                            (instant)
                                         → BillingQuotaCache.refresh()
                                            (clinical-svc.GetMyBillingState pull)

Usage commit (§3d)                      state_after on CommitUsage response
                                         (in-process consumer is stt-finalize, not Flutter)
                                         → Flutter sees the change on next refresh path:
                                            cold-start, next ReserveCredit, or quota-recovery listener

App cold-start                          BillingQuotaCache.refresh()
                                         → clinical-svc.GetMyBillingState
                                         (authoritative; one RPC)

Mid-session quota recovery              admin SQL bump → next RPC observes new tokens_remaining
(admin tops up tokens)                   → quota-recovery listener (commit eee4ef2) wakes parked
                                            upload rows via runner.resetBackoffsForColdStart()
                                            + runner.kick()
```

There is **no out-of-band channel** any more — no Pub/Sub, no Firestore mirror doc, no Cloud Function consumer, no FCM push for quota events. Edge-threshold computation (`warning` / `critical` / `exhausted` labels) was moved into Flutter (`billing_quota_state.dart::QuotaState.computeLevel`). The backend is the source of truth for `tokens_remaining`; the client decides what colour banner to render.

Trade-off: if a usage commit happens while the user is on the QuotaWarningBanner screen, they don't see the new count until either (a) they start a new recording (next ReserveCredit triggers refresh) or (b) they cold-restart the app. We accepted this per the Phase C plan — quota state is slowly-changing and the user is rarely staring at the banner waiting for it to update.

clinical-svc.GetMyBillingState is the only piece of new wiring; it's a thin proxy:

```go
// services/clinical-svc/internal/adapters/grpc/billing.go
1. Extract user_id from auth context (must be authenticated)
2. queries.GetUserOrganizationID(user_id)
3. billing.GetSubscription(GetSubscriptionRequest{OrganizationId: org_id})
4. Forward the Subscription proto back to the caller
```

Error taxonomy: `Unauthenticated` (no auth ctx), `NotFound` (user has no org — shouldn't happen post-trial-signup), `FailedPrecondition` (no active subscription — shouldn't happen post-trial-signup), `Unavailable` (billing-svc unreachable), pass-through for billing-svc errors. The billing client is constructed using `idtoken.NewTokenSource` (same OIDC pattern as ingestion-svc.billing wiring); `BILLING_SVC_URL` is required in the CI deploy env (commit `fe43420` added it for clinical-svc + ingestion-svc).

---

## 6. Notification-svc — no longer in the billing path

In v1.0 the worker consumed `billing.outbox` events to mirror state into Firestore and dispatch FCM. In v2.0 that whole path is gone.

What notification-svc still does (unchanged):
- Consumes `audio.uploaded` / `transcript.completed` / `report.generated` / `session.deleted` Pub/Sub topics
- Mirrors session lifecycle into `session_states/{session_id}` Firestore doc
- Writes per-user inbox notifications to `user_notifications/{firebase_uid}/inbox/{notif_id}`
- Sends FCM push for session lifecycle events ("Twoja sesja jest gotowa", etc.)

The Cloud Functions `notification-worker-on-uploaded`, `notification-worker-on-transcribed`, `notification-worker-on-report`, `notification-worker-on-deleted` still exist. Only `notification-worker-on-billing` was destroyed.

---

## 7. Periodic operations — Cloud Scheduler

`infra/environments/staging/billing_crons.tf` defines three scheduler jobs hitting billing-svc admin HTTP endpoints (`services/billing-svc/internal/adapters/http/admin_handler.go`):

| Cron | Schedule | Endpoint | Behavior |
|---|---|---|---|
| Reservation expiry | every 5 min | `POST /admin/reservation-expiry` | UPDATE pending_reservations SET status=EXPIRED WHERE status=ACTIVE AND expires_at < NOW(); decrements `tokens_reserved` |
| Manual period renewal | daily 02:00 | `POST /admin/manual-period-renewal` | For subs with billing_source=MANUAL: rolls usage_counters to new period when period_end < NOW() |
| Safety check | weekly Mon 06:00 | `POST /admin/safety-check` | Alerts on subscriptions without active counters |

Auth: `cloud-scheduler-billing@` SA with `roles/run.invoker` on billing-svc; OIDC token in the request.

**Note v2.0:** Manual period renewal no longer emits a `subscription.period_renewed` outbox event (the table is gone). Flutter discovers the new period via the next cold-start refresh — period rollover is once-a-month so this is fine.

---

## 8. Payment events (Stripe stub)

```
services/billing-svc/internal/adapters/http/stripe_stub.go
   POST /stripe/webhook
   │
   ├─ Verify Stripe signature (stub: noop; real impl pending)
   ├─ Switch event.type:
   │   ├─ invoice.paid          → rotate usage_counters period (per ADR-BL-003)
   │   ├─ customer.subscription.updated → update subscriptions.status
   │   └─ (other)               → log + 200 ACK
   └─ INSERT payment_events (audit trail, ADR-BL-002)
```

Stripe-side accountID + customerID are envelope-encrypted (`encrypted_customer_id` + DEK, ADR-BL-004); the gateway is currently disabled until production Stripe wiring.

---

## 9. Service map (final picture, v2.0)

```
┌─────────────────┐
│   Flutter       │── GetMyBillingState ─→ clinical-svc ── GetSubscription ─→ billing-svc
│                 │  (cold start +                                                    │
│                 │   post-Reserve refresh)                                           │
│  upload queue ──┼── CreateAudioUpload ──→ ingestion-svc ── ReserveCredit ─────────→│
│                 │                                                                   │
│  read transcript├── GetSessionDetails ──→ clinical-svc                              │
│                 │                                                                   │
│  session FCM    │← FCM (audio_uploaded, report_ready, etc. — NOT quota)            │
└────────┬────────┘                                                                   │
         │                                                                            │
         │ PUT audio                                                                  │
         ▼                                                                            │
  GCS audio-uploads ──OBJECT_FINALIZE──→ ingestion-svc subscriber                     │
         │                                                                            │
         ▼ (audio.uploaded)                                                           │
   stt-worker (CF) ─── Chirp ──→ GCS transcripts-raw                                  │
                                       │                                              │
                                       ▼ OBJECT_FINALIZE                              │
                                  stt-finalize (CF) ── CommitUsage ─────────────────→│
                                       │                                              │
                                       ▼                                              │
                              publishTranscriptCompleted                              │
                                       │                                              │
                                       ▼                                              │
                              llm-worker (CF)                                         │
                                       │                                              │
                                       ▼                                              │
                              publishReportGenerated                                  │
                                       │                                              │
   Cloud Scheduler ──OIDC POST──→ /admin/* ────────────────────────────────────────→ │
```

What's gone vs v1.0: no `outbox_events` table, no `billing.outbox` Pub/Sub topic, no `notification-worker-on-billing` CF, no `organization_quota/{org_id}` Firestore doc, no Flutter Firestore subscription for billing.

---

## 10. Hardening fixes shipped 2026-05-26 / 27 (both eras)

| Commit | Component | What broke without it |
|---|---|---|
| `d15f6e7` | terraform stt-finalize env | `BILLING_SVC_URL` was set on stt-worker but the actual code path runs in stt-finalize → CommitUsage was a no-op |
| `929e419` (v1) | billing-svc + notification-svc | (Superseded by Phase C) quota.updated emitted on every commit/reserve + mirror write moved before FCM title check |
| `fe92d48` | clinical-svc + llm-worker | Reverted broken canonical-blob read; added rebuildBlobWithRoles in llm-worker so the blob carries roles for future fast-reads |
| `1fceae0` | clinical-svc | Re-added canonical-blob fast path with strict role-marker gate (only used when blob has speaker_label populated; otherwise per-segment fallback) |
| `b752cea` | ingestion-svc | Synchronous ReserveCredit with hard-block on QUOTA_EXHAUSTED / FailedPrecondition; fail-soft for everything else |
| `7d876fc` | ingestion-svc | Idempotency cache-hit path now also calls reserveCreditOrBlock; closes the bypass where Flutter retries an over-quota upload short-circuited around the quota check |
| `761e2e4` | per-svc pgxpool caps | Bound `MaxConns` per service to fit the db-f1-micro 25-conn ceiling (ingestion 4, clinical 4, billing 2, identity 2, ai-pipeline 4, notification-svc 2, …) |
| `0a25ac7` | identity-svc | Auto-provision Trial org + 3-token subscription on therapist signup |
| `a147726` | migrations | `000033_trial_plan_seed` uses INSERT…WHERE NOT EXISTS (the partial unique index can't be referenced by ON CONFLICT) |
| `fe43420` | CI workflow | Added BILLING_SVC_URL to clinical-svc + ingestion-svc deploy `--set-env-vars` so CI redeploys don't strip the manually-set env block |
| `8774f17` | billing-svc proto + handlers (Phase A) | Subscription proto gains `plan_cycle` + `tokens_remaining`; Reservation + UsageCommit gain `state_after Subscription` so Flutter can update its cache from the gRPC response |
| `f99efe0` | clinical-svc (Phase B) | New `GetMyBillingState` RPC proxying billing-svc.GetSubscription; replaces the Firestore mirror as Flutter's cold-start hydration source |
| `cecc469` | Flutter (Phase B) | BillingQuotaCache + provider rewrite; drops `billing_quota_listener.dart` and the Firestore subscription |
| `634d2f9` | Phase C teardown | Removed outbox writes from ReserveCredit + CommitUsage; deleted outboxpoller / pubsub publisher / domain/outbox packages + Pub/Sub publisher init; removed `ProcessBillingEvent` from notification-svc worker; removed `OrganizationQuota` writer from firestore writer; terraform removed `notification-worker-on-billing` CF + `billing.outbox` topic/DLQ/IAM |
| `5aa2fe9` | migration 000034 | DROP TABLE outbox_events (one-way; intentionally split from 634d2f9 so CI deploys new images first, otherwise old billing-svc would INSERT against a dropped table for the ~7-min deploy window) |
| `93e96d5` | Flutter | UploadQueueRunner cold-start backoff reset — parked QUOTA_EXHAUSTED rows get one fresh attempt on app launch |
| `eee4ef2` | Flutter | Quota-recovery kick — listener on BillingQuotaCache fires on `tokensRemaining 0 → >0` and wakes parked uploads without an app restart |
| `778efd8` | Flutter | Fixed LateInitializationError in BillingQuotaNotifier on first signup; moved Subskrypcja entry from Kartoteki header to Settings → TWOJE KONTO |

---

## 11. Known open issues (v2.0)

| Issue | Status |
|---|---|
| `CommitUsage` has no quota check at commit (defense-in-depth gap) | Deferred — once `7d876fc` upstream gate is reliable this is belt-and-suspenders |
| Cloud SQL `db-f1-micro` with `max_connections=25` insufficient for 7 services under load | Deferred / monitor; pgxpool caps in `761e2e4` bought headroom; upgrade to `db-custom-1-3840` if recurrent |
| Stripe webhook is a stub | Production Stripe wiring pending |
| QuotaWarningBanner can be stale until next ReserveCredit or app restart | Accepted trade-off — see §5; backend has no out-of-band channel any more |
| Orphan `OutboxStatus` enum in PG (from migration 000002) | Cosmetic; leave for now, drop in a future schema-cleanup migration |
| Orphan `organization_quota/*` Firestore docs from v1.0 | Hidden by `firestore.rules` default-deny (rule removed in `eee4ef2`); one-shot cleanup script pending |

---

## 12. Debugging cheat sheet (v2.0)

When billing looks wrong, check these in order:

1. **Postgres** (authoritative):
   ```sql
   SELECT uc.tokens_used, uc.tokens_reserved, uc.tokens_limit,
          uc.period_start, uc.period_end, s.status, s.plan_tier
     FROM usage_counters uc
     JOIN subscriptions s ON s.id=uc.subscription_id
    WHERE s.organization_id = '<org_id>';
   ```

2. **Flutter's view via clinical-svc** (what the app actually sees):
   ```bash
   grpcurl -H "authorization: Bearer $FIREBASE_ID_TOKEN" \
     -d '{}' \
     clinical-svc-<hash>.run.app:443 \
     clinical.v1.ClinicalService/GetMyBillingState
   ```
   This should match Postgres. If it doesn't, look at the GetMyBillingState handler logs — most likely org_id resolution.

3. **billing-svc directly** (cuts out clinical-svc proxy):
   ```bash
   grpcurl -H "authorization: Bearer $OIDC_TOKEN" \
     -d '{"organization_id":"<org_id>"}' \
     billing-svc-<hash>.run.app:443 \
     billing.v1.BillingService/GetSubscription
   ```

4. **ReserveCredit calls** during a session upload:
   ```bash
   gcloud logging read 'resource.type=cloud_run_revision
     AND resource.labels.service_name=ingestion-svc
     AND (jsonPayload.msg=~"reserve" OR jsonPayload.msg=~"QUOTA")
     AND jsonPayload.session_id="<session_id>"' --freshness=2h
   ```

5. **CommitUsage calls** at finalize:
   ```bash
   gcloud logging read 'resource.type=cloud_run_revision
     AND resource.labels.service_name=stt-finalize
     AND jsonPayload.msg="billing commit: tokens committed"
     AND jsonPayload.session_id="<session_id>"' --freshness=2h
   ```

6. **Reservations** still active for the org:
   ```sql
   SELECT session_id, status, tokens_reserved, expires_at, created_at
     FROM pending_reservations
    WHERE organization_id = '<org_id>'
      AND status = 'ACTIVE'
    ORDER BY created_at DESC;
   ```
   If `expires_at < NOW()` and status is still ACTIVE the reservation-expiry cron hasn't run / is failing.

7. **Trial signup auto-provisioning** for a freshly-registered therapist:
   ```sql
   SELECT u.id, u.email, u.organization_id, o.legal_name, s.plan_tier, s.status, uc.tokens_limit
     FROM users u
     JOIN organizations o ON o.id = u.organization_id
     JOIN subscriptions s ON s.organization_id = o.id
     JOIN usage_counters uc ON uc.subscription_id = s.id
    WHERE u.email = '<email>';
   ```
   Expect: `plan_tier=TRIAL`, `status=TRIALING`, `tokens_limit=3`.
