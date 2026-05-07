---
description: Loads when editing ingestion-svc (signed URLs, upload tickets, GCS, OLM 48h).
globs:
  - "superwizor-backend/services/ingestion-svc/**"
  - "superwizor-backend/proto/ingestion/**"
  - "superwizor-backend/gen/go/ingestion/**"
  - "superwizor-backend/migrations/*ingestion*.sql"
  - "superwizor-backend/migrations/*audio_uploads*.sql"
  - "superwizor-backend/migrations/*upload_tickets*.sql"
  - "superwizor-backend/infra/modules/storage/**"
  - "superwizor-backend/infra/modules/audio-storage/**"
alwaysApply: false
---

# ingestion-svc

**Read [`docs/agents/04_ingestion-svc.md`](../../docs/agents/04_ingestion-svc.md) before editing.**

Quick orientation:

- **The "secure upload door".** Issues V4 GCS signed URLs (PUT, 15min TTL, max 300MB, `audio/m4a`). Flutter PUTs directly to GCS — **NEVER stream audio through this service.**
- **Tables owned:** `audio_uploads` (state machine PENDING→UPLOADED→TRANSCRIBING→...), `upload_tickets`.
- **OLM 48h** on audio bucket is the P1 backstop — don't extend past 48h. `stt-worker` deletes explicitly after successful transcription.
- **Idempotency:** `audio_uploads.idempotency_key UNIQUE`; reusing a key with different payload is a contract violation.
- **Pub/Sub v2 only.** `client.Publisher("audio.uploaded")`. Always `defer publisher.Stop()` to avoid goroutine leak.
- **Dedicated SA** `ingestion-svc@${PROJECT}` with `roles/iam.serviceAccountTokenCreator` on **itself** (required for self-signing URLs).
- **Pre-flight gate:** call `billing-svc.CheckQuota(usage_type="session_analysis")` before signing.
- **Public Cloud Run** with `allUsers → roles/run.invoker`; Firebase token validated in app layer.
