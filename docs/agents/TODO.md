# Backend TODO

Tracked-but-not-yet-scheduled items. Each entry: what's broken, why it matters, where the bug actually is, and how big the fix is. Keep entries terse. Promote to a real ticket / branch when someone picks it up; remove from this file when shipped.

---

## High priority

### Idempotency keys are silently ignored on every RPC that declares one

**Status**: not started. Plan written in commit conversation 2026-05-12 (see "Plan: Fix broken idempotency_key on CreatePatientFile"). Spawned ccd task exists but hasn't been executed.

**What's broken**: three RPCs declare `idempotency_key` in their request proto but no handler actually checks the value. A client retry creates a duplicate row. The proto comment / field's mere existence implies a contract that the server doesn't honor.

| Proto | Field | RPC | Currently ignored? |
|---|---|---|---|
| `clinical/v1/clinical.proto:99` | `CreatePatientFileRequest.idempotency_key` | `CreatePatientFile` | yes — confirmed on staging, 11 duplicate rows from e2e retries |
| `ingestion/v1/ingestion.proto:26` | `CreateAudioUploadRequest.idempotency_key` | `CreateAudioUpload` | yes — same pattern; unverified on staging but no de-dup code exists |
| `billing/v1/billing.proto:40` | `IncrementUsageRequest.idempotency_key` | `IncrementUsage` | yes — **higher stakes**: double-charges if Cloud Run retries a request, since IncrementUsage is the entitlement-gate write path |

**Evidence (clinical)**: e2e happy-path retries with same key produce two distinct DB rows ~100ms apart. Post-migration 000013 the second call hits the `working_alias` unique index and returns `AlreadyExists` — masking the real bug. The e2e test had to be loosened (`tolerate AlreadyExists on idempotency replay`, commit `aaf6464`) to keep running.

**Recommended fix shape** (lenient mode, per-resource column — full design in the conversation plan):

- New column `idempotency_key VARCHAR(255)` on each affected table (`patient_files`, `audio_uploads`, `usage_events` or wherever `IncrementUsage` writes).
- Partial unique index `(therapist_id, idempotency_key) WHERE idempotency_key IS NOT NULL AND deleted_at IS NULL` per table.
- Handler path: pre-check by key before the create transaction; if hit, short-circuit + return the cached row (skip child inserts like `patient_user`, skip audit log, skip side effects).
- INSERT uses `ON CONFLICT (therapist_id, idempotency_key) WHERE … DO NOTHING RETURNING *` with a `UNION ALL SELECT FROM existing` fallback so the call is atomic.
- Empty/NULL key → opt-out, current behavior preserved (always create).

**Scope decisions baked into the plan**:
- **Lenient mode** (same key + different payload → still return first call's row). Strict mode (payload hashing) is deferred.
- **No TTL** on stored keys (Stripe expires at 24h; we don't need it yet).
- **Per-resource column**, not a shared `idempotency_keys` table. YAGNI — repeat the pattern when needed.

**Order to fix** (start narrow, prove the pattern, then repeat):

1. **CreatePatientFile** first — smallest blast radius, has e2e coverage already.
2. **IncrementUsage** next — highest financial risk if a Cloud Run retry double-counts.
3. **CreateAudioUpload** last — biggest payload, but audio upload retries are usually self-correcting (the GCS PUT is idempotent on the same signed URL).

**E2E follow-ups when each lands**:
- `tests/e2e/full_session_test.go::TestFullSession_HappyPath` Step 3 — flip the lenient three-branch switch back to `require.Equal(t, patient.Id, patient2.Id)`. Currently logs `⚠ Idempotency NOT implemented` and proceeds.
- Add a dedicated `TestE2E_IdempotencyReplay` in `tests/e2e/patient_lifecycle_test.go` that explicitly calls the same RPC twice and asserts equal ids + no side effect from the second call (Get patient count = 1).

**Estimated diff per RPC**: ~150 LOC + a migration + 5-10 unit tests. ~3 hours each.

---

### Wire DLQ on Eventarc-managed Pub/Sub subscriptions

**Status**: not started. Worker-side poison-guard partially mitigates
(stt-worker shipped with `loadSessionStatus` check 2026-05-15) but
the DLQ should still exist as a safety net for messages that don't
correspond to a session row at all (e.g. malformed events).

**What**: stt-worker / llm-worker Eventarc triggers create their own
Pub/Sub subscriptions under the hood (`eventarc-europe-central2-*-sub-*`).
These subscriptions DON'T have `deadLetterPolicy` set, even though
our terraform `module.pubsub` declares the DLQ topics
(`audio.uploaded.dlq`, `transcript.completed.dlq`). So poison
messages retry for the full 24h retention window before aging out,
with no DLQ exit.

**Evidence (2026-05-14 → 2026-05-15)**: session `b6c7a606` failed first
delivery at 15:52 UTC on 5/14 (Chirp `code=13 INTERNAL` on a
multi-language audio request). Same message redelivered every ~7-10
min for 24+ hours, ~100 retry attempts. Drained manually via
`gcloud pubsub subscriptions seek SUB --time=NOW`.

**Where**:
  - Eventarc trigger config — `infra/modules/cloud-functions/main.tf`,
    `event_trigger { ... }` blocks on `stt_worker` and `llm_worker`
  - DLQ topics already in `infra/modules/pubsub/main.tf`

**Why now**: keeps biting. Every operator-side mistake or transient
Chirp/Vertex outage produces a 24h log-noise tail.

**Fix shape**: two options:
  1. Add `dead_letter_config` to the Eventarc `event_trigger` block.
     The Cloud Functions Gen2 API supports it on Eventarc-managed
     triggers as of the late-2024 SDK. Verify the provider exposes
     the field; if so, single-line terraform addition per worker.
  2. If the provider doesn't expose it: post-create patch the
     subscription via a `google_pubsub_subscription` data lookup +
     dependent IAM. Fiddlier; keep as fallback.

Also add explicit retry-policy `max_delivery_attempts` so messages
drain after N tries instead of riding the 24h retention.

**Tests**: an explicit poison-message test on staging — drop an
unprocessable audio path into the queue, verify DLQ topic receives
the message after the retry budget, verify main subscription stops
retrying. ~30 min of manual testing once the terraform change lands.

---

## Lower priority / unscheduled

_(no entries — extract-constants TODO shipped on feat/report-customization)_

---

Add entries here as they surface. Format:

> ### Short description
> **Status**: not started / in progress (branch name) / blocked-on (X)
> **What** / **Where** / **Why now** / **Fix shape**
