# 17. Billing — End-to-End Implementation Flow

**Version:** 1.0 (2026-05-27)
**Status:** Current live behavior on staging. Snapshot of the deployed billing pipeline.
**Related:** `16_BILLING_SERVICE_PHASE_3.md` (canonical design), `agents/03_billing-svc.md` (service-level reference), `agents/00_GLOBAL_CONTEXT.md`.

This document maps the production-grade flow as it actually runs in staging — every component, every gRPC / Pub/Sub hop, every Firestore write — for a single session from app launch through quota enforcement, STT, LLM, and notification mirror. Use it when debugging a billing bug or onboarding to the system.

For the *why* (design rationale, ADRs, threshold tuning), read §16 first.

---

## 0. Boot state — data model

```
organizations (T1.. T222 — bootstrapped by /tmp/dbq/seed_orgs.go)
   ├── 1:1 → subscriptions (plan_tier: SOLO|PRO|CLINIC, plan_cycle: MONTHLY|ANNUAL, status: ACTIVE|PAST_DUE)
   │                            │
   │                            └─ 1:1 → usage_counters (per active period)
   │                                       ├── tokens_limit  (from plan: 20 / 100 / 500)
   │                                       ├── tokens_used   (consumed)
   │                                       ├── tokens_reserved (held but not yet consumed)
   │                                       ├── period_start  (e.g. 2026-05-01)
   │                                       └── period_end    (e.g. 2026-06-01)
   │
   └── 1:N → users (therapists)

pending_reservations     — UNIQUE on session_id; status ACTIVE|EXPIRED|COMMITTED|RELEASED; TTL 4h
usage_events             — UNIQUE on session_id; the "commit" record (tokens_consumed, duration_seconds)
outbox_events            — billing-svc's transactional outbox; aggregate_type=quota
subscription_plans       — catalog: 6 rows (SOLO/PRO/CLINIC × MONTHLY/ANNUAL)
payment_events           — payment gateway audit (Stripe events, currently stubbed)
```

Token semantics (ADR-DM-017): `1 token = up to 60 min audio + 180 s grace` →
`tokens = max(1, ceil((duration_s − 180) / 3600))`.

`remaining = limit − used − reserved`. Edge thresholds (`outbox.DefaultThresholds`):
warning at `remaining ≤ 5`, critical at `remaining ≤ 1`, exhausted at `remaining == 0`.

---

## 1. App startup — Flutter reads the mirror

```
Flutter app launches
   │
   ├─ currentUserProvider  → identity-svc.GetUser  → returns user.organization_id
   │
   └─ billingQuotaProvider.build()
       │
       └─ Firestore stream:  organization_quota/{org_id}     ← single doc per org
           │
           ↓
       fields: tokensUsed, tokensReserved, tokensLimit, tokensRemaining,
               warningLevel (none|warning|critical|exhausted), planTier, planCycle,
               periodStart, periodEnd, updatedAt (serverTimestamp)
```

Backend is the **only writer** to `organization_quota/{org_id}` (enforced by Firestore rules).
Flutter is read-only — it does **NOT** call `billing-svc.GetUsage` on startup; it relies entirely on the live Firestore stream.

UI consumers:
- `lib/widgets/quota_warning_banner.dart` — sticky banner on `home_screen.dart` above the "Aktywne kartoteki" list
- `lib/widgets/pending_quota_sessions_widget.dart` — patient-scoped, on `client_details_screen.dart`
- `lib/widgets/quota_exhausted_dialog.dart` — fired when `ReserveCredit` returns `ResourceExhausted`
- `lib/screens/subscription_plan_screen.dart` — full quota view from menu

---

## 2. Record + Submit — quota gate at upload time

### 2a. Flutter side

```
RecordingScreen → user stops recording
   │
   └─ UploadQueueRunner.enqueue()    (lib/uploads/upload_queue_runner.dart)
       ↓
   PendingUpload row in local SQLite, phase=pending
       ↓
   For each attempt:
     ingestionClient.CreateAudioUpload(
       therapist_id, patient_file_id, content_type,
       estimated_size_bytes, idempotency_key=<uuid-v4 per attempt>,
       client_platform, client_app_version
     )
```

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
   └─ HIT → return existing reservation  (idempotent on session_id)

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

   3f. AppendOutboxEvent(
         aggregate=quota,
         event_type="quota.updated",                          ← commit 929e419
         payload={org_id, plan_tier, plan_cycle,
                  tokens_used, tokens_reserved+N, tokens_remaining,
                  period_start, period_end, subscription_id}
       )

   3g. tx.Commit
4. Return Reservation{reservation_id, session_id, tokens, expires_at}
```

### 2d. Flutter post-response

```
CreateAudioUploadResponse received
   ├─ OK                       → PUT audio to signed URL, advance phase to "created"
   │                              billingQuotaProvider.applyLocalReservation(1)
   │                                 (optimistic decrement until Firestore catches up)
   │
   └─ ResourceExhausted        → show QuotaExhaustedDialog
       FailedPrecondition       (no PUT happens; orphan session+upload rows
                                 expire via audio_uploads.expires_at TTL)
```

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
   └─ HIT  → return UsageCommit (idempotent)        ← session_id UNIQUE constraint

2. Begin tx + AcquireSubscriptionLock + LockActiveCounter

3. tokens_to_charge = tokens.Calculate(duration_seconds)
                    = max(1, ceil((duration − 180) / 3600))

4. CreateUsageEvent(session_id, sub_id, org_id, tokens, duration_seconds, usage_type)

5. GetReservationBySession(session_id)
   ├─ ACTIVE → reserved_to_release = reservation.tokens_reserved
   │           MarkReservationCommitted(session_id)
   └─ none    → reserved_to_release = 0
                ↑ KNOWN GAP: no quota check at commit. Counter can go over
                  if upstream allowed an upload past the gate. Defense in
                  depth pending — see §11.

6. CommitTokens(counter_id, +tokens_to_charge, -reserved_to_release)

7. Compute remaining_before / remaining_after
   AppendOutboxEvent(
     event_type = QuotaEdgeEventType(before, after)  // "quota.warning"
                  || "quota.critical"
                  || "quota.exhausted"
                  || (if no edge crossed) "quota.updated"     ← commit 929e419
     payload = {tokens_used+N, tokens_reserved-released, tokens_remaining, …}
   )

8. tx.Commit
9. Return UsageCommit{tokens_consumed, remaining_tokens, limit_tokens}
```

---

## 4. LLM analysis — role assignment + blob rebuild

```
llm-worker (entry: ProcessTranscript) consumes transcript.completed
   │
   ├─ loadTranscriptBlob(transcript_id)             ← 1 KMS decrypt
   ├─ generateReport (Vertex AI Gemini)
   ├─ persistReport (encrypted)
   │
   ├─ generateAndSaveSpeakerLabels:
   │     │  services/ai-pipeline-svc/cmd/llm-worker/main.go::generateAndSaveSpeakerLabels
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

## 5. Outbox poller → Pub/Sub → notification mirror

```
billing-svc has an in-process poller goroutine (outboxpoller/poller.go)
   │
   loop every 1s:
     ├─ ListUnpublishedOutboxEvents FOR UPDATE SKIP LOCKED LIMIT 100
     ├─ For each event:
     │    ├─ Publish to Pub/Sub topic billing.outbox  with attributes
     │    │     event_type, organization_id, idempotency_key, aggregate_type
     │    └─ MarkOutboxEventPublished(id)
     └─ tx.Commit


Pub/Sub billing.outbox  → Eventarc → notification-worker-on-billing (Cloud Function Gen2)
   services/notification-svc/cmd/worker/main.go::ProcessBillingEvent
   │
   1. Extract Pub/Sub attributes (event_type, organization_id, idempotency_key)
   2. Unmarshal BillingEventPayload
   3. store.LookupBillingNotificationTarget(org_id)  → user_id, firebase_uid, locale
   4. InsertNotificationDelivery(idempotency_key)    ← idempotency UNIQUE on key
   5. WriteOrganizationQuota(...)                    ← Firestore mirror (commit 929e419)
       │
       └─ FIRST, before localize / FCM dispatch. So non-push events (quota.updated)
          still refresh the mirror.
   6. localizeBillingEvent(locale, event_type, payload) → (title, body)
       ├─ quota.warning|critical|exhausted|period_renewed → non-empty title
       └─ quota.updated | unknown                          → empty title (skip push)
   7. If title != "":
        ├─ ListActiveFCMTokensByUser → tokens
        ├─ fcmSender.Send(title, body, NotificationType=event_type)
        ├─ Update token validity (InvalidateFCMToken on not_registered)
        ├─ UpdateNotificationDeliveryStatus(sent|failed|token_invalid)
        └─ WriteInboxNotification (Firestore user_notifications/{uid}/inbox)
   8. Else:
        UpdateNotificationDeliveryStatus(skipped, code=no_push_body)
```

The Cloud Function shares its source with the `notification-svc` Cloud Run service — both deploy from the same zip via the `infra/modules/cloud-functions` terraform module. Updating only the Cloud Run service without redeploying the function (`notification-worker-on-billing`) was a subtle deploy bug we hit twice — see §11.

---

## 6. Flutter receives the update

```
Firestore organization_quota/{org_id} document changes
   ↓ (live stream subscribed in billing_quota_listener.dart)
BillingQuotaListener emits new QuotaState
   ↓
billingQuotaProvider (Riverpod AsyncNotifier) resets local offset, propagates state
   ↓
   ├─ QuotaWarningBanner re-renders with new warning level
   ├─ PendingQuotaSessionsWidget recomputes
   ├─ SubscriptionPlanScreen recounts remaining
   └─ (no FCM push for quota.updated — only edge events generate one)
```

If the user is offline / app backgrounded, the FCM push (when an edge event fires) wakes them. On next foreground Firestore reconnect, the mirror catches up.

---

## 7. Periodic operations — Cloud Scheduler

`infra/environments/staging/billing_crons.tf` defines three scheduler jobs hitting billing-svc admin HTTP endpoints (`services/billing-svc/internal/adapters/http/admin_handler.go`):

| Cron | Schedule | Endpoint | Behavior |
|---|---|---|---|
| Reservation expiry | every 5 min | `POST /admin/reservation-expiry` | UPDATE pending_reservations SET status=EXPIRED WHERE status=ACTIVE AND expires_at < NOW(); decrements `tokens_reserved` |
| Manual period renewal | daily 02:00 | `POST /admin/manual-period-renewal` | For subs with billing_source=MANUAL: rolls usage_counters to new period when period_end < NOW(); emits subscription.period_renewed outbox event |
| Safety check | weekly Mon 06:00 | `POST /admin/safety-check` | Alerts on subscriptions without active counters |

Auth: `cloud-scheduler-billing@` SA with `roles/run.invoker` on billing-svc; OIDC token in the request.

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

## 9. Service map (final picture)

```
┌─────────────────┐
│   Flutter       │── reads ─→ Firestore organization_quota/{org_id}
│                 │
│  upload queue ──┼── CreateAudioUpload ──→ ingestion-svc ──┐
│                 │                                          │ Cloud Run
│  read transcript├── GetSessionDetails ──→ clinical-svc ──┐ │
│                 │                                          │ │
│  records FCM    │← FCM push                                │ │
└────────┬────────┘                                          │ │
         │                                                   │ │
         │ PUT audio                                         ▼ ▼
         ▼                                              ┌─────────┐
  GCS audio-uploads ──OBJECT_FINALIZE──→ ingestion-svc │ billing-│
         │                              subscriber ──→ │   svc   │
         │                                              │         │
         ▼ (audio.uploaded)                             │  ReserveCredit
   stt-worker (CF) ─── Chirp ──→ GCS transcripts-raw    │  CommitUsage
                                       │                │  ReleaseCredit
                                       ▼ OBJECT_FINALIZE│  CheckQuota
                                  stt-finalize (CF) ───→│  IncrementUsage(legacy)
                                       │                │           │
                                       │ CommitUsage    │           │ outbox
                                       ▼                │           ▼
                              publishTranscriptCompleted│      Pub/Sub
                                       │                │      billing.outbox
                                       ▼                │           │
                              llm-worker (CF)           │           ▼
                                       │                │   notification-worker-
                                       │ generateAndSave│   on-billing (CF)
                                       │ SpeakerLabels  │           │
                                       │ rebuildBlobWithRoles       ├─→ Firestore mirror
                                       │                │           ├─→ FCM push (edge only)
                                       ▼                │           └─→ notification_deliveries
                              publishReportGenerated    │
                                                        │
   Cloud Scheduler ──OIDC POST──→ /admin/* ─────────────┘
```

---

## 10. Hardening fixes shipped 2026-05-26 / 27

| Commit | Component | What broke without it |
|---|---|---|
| `d15f6e7` | terraform stt-finalize env | `BILLING_SVC_URL` was set on stt-worker but the actual code path runs in stt-finalize → CommitUsage was a no-op |
| `929e419` | billing-svc + notification-svc | quota.updated emitted on every commit/reserve (not just edges) AND mirror write moved before FCM title check → non-edge events refresh Flutter's view |
| `fe92d48` | clinical-svc + llm-worker | Reverted broken canonical-blob read; added rebuildBlobWithRoles in llm-worker so the blob carries roles for future fast-reads |
| `1fceae0` | clinical-svc | Re-added canonical-blob fast path with strict role-marker gate (only used when blob has speaker_label populated; otherwise per-segment fallback) |
| `b752cea` | ingestion-svc | Synchronous ReserveCredit with hard-block on QUOTA_EXHAUSTED / FailedPrecondition; fail-soft for everything else |
| `7d876fc` | ingestion-svc | Idempotency cache-hit path now also calls reserveCreditOrBlock; closes the bypass where Flutter retries an over-quota upload short-circuited around the quota check |
| `8cdcec2` | Flutter | Step 1 of session-status stepper renders "Audio waiting in upload queue" while phase==pending instead of the misleading "Audio safely on our servers" |
| `6e9aa9d` | Flutter | QuotaWarningBanner moved from kartoteka detail → home_screen above the Aktywne kartoteki list (visible before drilling in) |
| `e7a1fc1` | Flutter | Removed the placeholder "Rozszerz plan" CTA from QuotaWarningBanner (the banner is informational; plan management lives in SubscriptionPlanScreen) |

---

## 11. Known open issues

| Issue | Status |
|---|---|
| `CommitUsage` has no quota check at commit (defense-in-depth gap) | Deferred — once `7d876fc` upstream gate is reliable this is belt-and-suspenders |
| Cloud SQL `db-f1-micro` with `max_connections=25` insufficient for 7 services under load | Deferred / monitor; consider `db-custom-1-3840` upgrade if recurrent |
| Stripe webhook is a stub | Production Stripe wiring pending |
| Backfill blob for pre-`fe92d48` sessions | On-demand; Marcin's blob was already role-populated by chance |
| Counter overage from the bug window (e.g. Dario at used=24/limit=20) | Resolves on period rollover; manual reversal possible if needed |

---

## 12. Debugging cheat sheet

When billing looks wrong, check these in order:

1. **Postgres**:
   ```sql
   SELECT uc.tokens_used, uc.tokens_reserved, uc.tokens_limit
     FROM usage_counters uc
     JOIN subscriptions s ON s.id=uc.subscription_id
    WHERE s.organization_id = '<org_id>';
   ```
   This is authoritative.

2. **Firestore mirror**:
   ```bash
   TOKEN=$(gcloud auth print-access-token)
   curl -s -H "Authorization: Bearer $TOKEN" \
     "https://firestore.googleapis.com/v1/projects/superwizor-ai-25ecd/databases/(default)/documents/organization_quota/<org_id>"
   ```
   If this is stale vs PG, look at `notification-worker-on-billing` logs for the missed event.

3. **Outbox events** for the org:
   ```sql
   SELECT created_at, event_type, published_at, payload->>'tokens_used' AS used
     FROM outbox_events
    WHERE payload->>'organization_id' = '<org_id>'
    ORDER BY created_at DESC LIMIT 10;
   ```
   `published_at IS NULL` means the poller hasn't shipped it yet.

4. **Pub/Sub delivery** to `notification-worker-on-billing`:
   ```bash
   gcloud logging read 'resource.type=cloud_run_revision
     AND resource.labels.service_name="notification-worker-on-billing"
     AND jsonPayload.organization_id="<org_id>"' \
     --limit=20 --freshness=1h
   ```

5. **ReserveCredit calls** during a session upload:
   ```bash
   gcloud logging read 'resource.type=cloud_run_revision
     AND resource.labels.service_name=ingestion-svc
     AND (jsonPayload.msg=~"reserve" OR jsonPayload.msg=~"QUOTA")
     AND jsonPayload.session_id="<session_id>"' --freshness=2h
   ```

6. **CommitUsage calls** at finalize:
   ```bash
   gcloud logging read 'resource.type=cloud_run_revision
     AND resource.labels.service_name=stt-finalize
     AND jsonPayload.msg="billing commit: tokens committed"
     AND jsonPayload.session_id="<session_id>"' --freshness=2h
   ```
