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

## Lower priority / unscheduled

### llm-worker: extract generation-config knobs to named constants

**Status**: not started.

**What**: today `services/ai-pipeline-svc/cmd/llm-worker/main.go` has three
`model.GenerationConfig = vertexai.GenerationConfig{...}` blocks with raw
numbers (Temperature, TopP, MaxOutputTokens) inlined at each call site.
Two distinct profiles by design:

  - Metadata (call 1): Temperature 0.1, MaxOutputTokens 16384
  - Report   (call 2): Temperature 0.3, MaxOutputTokens 65535
  - TopP 0.95 shared

**Why now (eventually)**: maintainer briefly thought 65535 was a typo for
16384 — easy mistake when three call sites have different inlined numbers.
Named constants make the design intent (two profiles, by design) visible.

**Fix shape**: pull into package-level `geminiTempMetadata`,
`geminiTempReport`, `geminiTopP`, `geminiMaxOutMetadata`, `geminiMaxOutReport`
constants near the existing `geminiModel`/`geminiRegion` block. Substitute
at the three call sites. ~30 LOC delta, no behavior change. Either pure
constants, or a tiny pair of helper funcs (`metadataGenConfig` /
`reportGenConfig`) — bare constants are enough.

**Out of scope**: any further consolidation of the actual prompt strings.
The prompt text is correctly different across call 1 (JSON), call 1
(Markdown cluster), call 1 (Markdown role-only), and call 2 (report) —
each job has different output constraints. See the audit notes on the
2026-05-14 conversation thread for the rationale.

---

Add entries here as they surface. Format:

> ### Short description
> **Status**: not started / in progress (branch name) / blocked-on (X)
> **What** / **Where** / **Why now** / **Fix shape**
