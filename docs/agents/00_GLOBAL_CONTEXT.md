# Global Context — SuperWizor AI

> Read this **before** any per-area file. Everything below is project-wide invariant and applies to every service, the Flutter app, the infrastructure, and CI.

## What this product is

A clinical session co-pilot for psychotherapists in Poland. A therapist records a session in the Flutter mobile app; audio is transcribed (Chirp 3), an LLM (Gemini 2.5 PRO) produces a structured clinical report and HiTOP measurements, and the therapist receives the report. Long-running clinical memory ("RAG") accrues per patient and feeds future sessions.

**Hard product constraints:**
- Polish (`pl-PL`) is the only supported language for STT in v1.
- Audio is deleted from GCS after transcription (OLM 48h dead-man-switch as backup). The transcript becomes the source of truth.
- The Flutter app NEVER writes reports. It only reads them. Report generation is exclusively backend (AI pipeline).

## Five non-negotiable principles (P1–P5)

| # | Principle | Tech consequence |
|---|---|---|
| **P1** | **Zero Data Loss** | Idempotency at every pipeline step; at-least-once Pub/Sub delivery; OLM 48h backstop on audio buckets |
| **P2** | **Zero Trust** | Every service has a dedicated SA with minimum IAM; service-to-service via VPC connector or private IP only |
| **P3** | **Iron Localization** | Everything in `europe-central2`; org policy blocks other regions |
| **P4** | **Flutter is read-only on AI reports** | Firestore rules + IAM + gRPC contracts enforce no-write of reports from mobile |
| **P5** | **Readability > DB micro-optimization** | Normalized PostgreSQL schema; separate `therapist_view` and `patient_view` tables |

> Source: `docs/02_ARCHITEKTURA_TECHNICZNA.md` §1.1, lines 33–41.

## Architectural decision baseline (ADRs)

### Top-level ADR-001 to ADR-008 (architecture)
| ADR | Decision |
|---|---|
| ADR-001 | Cloud Run is the only compute layer (services + Cloud Functions Gen2 for workers) |
| ADR-002 | Cloud SQL PostgreSQL 16 + pgvector (RAG without separate vector store) |
| ADR-003 | **Go 1.26.2** (note: source doc says 1.23 but actual `go.work` is 1.26.2) |
| ADR-004 | Pub/Sub for async pipeline (at-least-once + DLQ + retry policy) |
| ADR-005 | gRPC for sync inter-service calls; `.proto` in repo |
| ADR-006 | Firestore is mobile sync layer ONLY — never source of truth |
| ADR-007 | Monorepo with Go workspaces (`go.work`) |
| ADR-008 | Terraform + Cloud Build (IaC from day zero) |

### Data-model ADRs (DM-001 to DM-016)
| ADR | Decision |
|---|---|
| ADR-DM-001 | UUID v4 PKs (no bigserial) |
| **ADR-DM-002** | **Envelope encryption for PHI columns: `<field>_ciphertext` + `<field>_encrypted_dek`** |
| ADR-DM-003 | Soft delete via `deleted_at` (GDPR audit trail) |
| ADR-DM-004 | RBAC via `users.role` enum (THERAPIST/PATIENT only) |
| ADR-DM-005 | Therapist↔Patient as M:N |
| ADR-DM-006 | HiTOP as closed ontology (lookup tables, no LLM hallucination) |
| ADR-DM-007 | Optimistic locking via `revision_number` on memory |
| ADR-DM-008 | Patient-facing data isolated to `patient_views` |
| **ADR-DM-009** | **Outbox pattern for Pub/Sub publishing (transactional)** |
| ADR-DM-010 | All FKs `ON DELETE RESTRICT` (force explicit cascade) |
| ADR-DM-011 | Feedback as separate domain (not columns on reports) |
| ADR-DM-016 | Invoicing via external SaaS (Fakturownia/iFirma); only `payment_events` retained |

### Phase-2 implementation ADRs (IMPL-001 to IMPL-007)
| ADR | Decision |
|---|---|
| ADR-IMPL-001 | Chirp 3 (not Chirp 2) for STT |
| ADR-IMPL-002 | Neutral localized speaker labels ("Osoba 1", "Osoba 2"); no role heuristics in STT |
| ADR-IMPL-003 | Gemini 2.5 PRO via Vertex AI |
| ADR-IMPL-004 | Cloud Functions Gen2 as workers (not Cloud Run services) |
| ADR-IMPL-005 | `billing-svc` is a stub in Phase 2; full Stripe in Phase 3 |
| **ADR-IMPL-006** | **`transcripts.transcript_ciphertext` is the source of truth (canonical blob); `transcript_segments` are derived** |
| **ADR-IMPL-007** | **LLM-inferred diarization for Polish** (Chirp 3 native diarization doesn't support `pl-PL`); `chunker.ChunkByPauses` segments by pauses ≥600ms, LLM clusters speakers |

> Sources: `docs/02_*.md` §1.2, `docs/03_*.md` §1.2, `docs/06_*.md` §"Decyzje architektoniczne".

## Repo layout

```
superwizor_v2/
├── ai/                          # this repo (the product)
│   ├── superwizor-backend/      # Go monorepo
│   │   ├── go.work              # workspace file (Go 1.26.2)
│   │   ├── proto/               # canonical .proto sources
│   │   ├── gen/go/              # generated proto stubs (committed; CI re-runs `buf generate`)
│   │   ├── pkg/                 # shared libraries
│   │   │   ├── authz/           # permission checks (stub)
│   │   │   ├── cryptobox/       # KMS envelope encryption
│   │   │   ├── errors/          # gRPC error mapping
│   │   │   ├── i18n/speakerlabels/  # neutral speaker label generation
│   │   │   ├── idempotency/     # idempotency key middleware
│   │   │   ├── logging/         # slog wrapper
│   │   │   ├── observability/   # OpenTelemetry init
│   │   │   ├── pubsubx/         # Pub/Sub helpers
│   │   │   ├── testutil/        # test fixtures
│   │   │   └── transcription/chunker/  # pause-based segmentation
│   │   ├── services/
│   │   │   ├── identity-svc/    # Firebase Auth + user/org CRUD
│   │   │   ├── clinical-svc/    # patient files, sessions, reports
│   │   │   ├── billing-svc/     # stub gRPC; quota checks
│   │   │   ├── ingestion-svc/   # signed URLs, upload tickets
│   │   │   ├── ai-pipeline-svc/ # gRPC server + cmd/stt-worker + cmd/llm-worker (Cloud Functions Gen2)
│   │   │   ├── analytics-svc/   # HiTOP read API (Phase 3)
│   │   │   ├── notification-svc/# FCM + Firestore writer (Phase 3)
│   │   │   ├── api/             # API gateway (legacy?)
│   │   │   ├── hello-world/     # health check service
│   │   │   └── migrator/        # Cloud Run Job that runs migrations
│   │   ├── migrations/          # golang-migrate SQL (000001 → 000008+)
│   │   └── infra/               # Terraform / Terragrunt
│   │       ├── environments/staging/
│   │       └── modules/         # vpc, cloud-sql, kms, pubsub, storage,
│   │                            # cloud-functions, migrations, audio-storage,
│   │                            # artifact-registry, audit-logs, wif, ...
│   ├── flutter-app/superwizor/  # Flutter therapist app
│   ├── docs/                    # canonical architecture (Polish)
│   │   └── agents/              # ← these focused per-area docs
│   ├── proxy.log, sa-key.json, ...  # local dev artifacts (mostly gitignored)
│   └── .github/workflows/ci.yml # CI/CD
```

**GCP project (staging):** `superwizor-ai-25ecd`. Region: `europe-central2`. Cloud SQL instance: `superwizor-db-bc4c27de`.

## Domain → service ownership

| Domain | Tables | Owner |
|---|---|---|
| **Identity** | `users`, `organizations`, `addresses`, `user_roles` | `identity-svc` |
| **Billing** | `subscription_plans`, `subscriptions`, `payment_events`, `usage_counters` | `billing-svc` (stub in Phase 2) |
| **Clinical** | `modalities`, `patient_files`, `therapist_patient_relations` | `clinical-svc` |
| **Sessions** | `sessions`, `transcripts`, `transcript_segments`, `therapist_reports`, `patient_views`, `audio_uploads`, `upload_tickets` | `clinical-svc` (CRUD), `ai-pipeline-svc` (writes from pipeline) |
| **Memory (RAG)** | `clinical_memory`, `memory_revisions`, `embedding_chunks`, `rag_memories` | `ai-pipeline-svc` |
| **Analytics (HiTOP)** | `hitop_dimensions`, `hitop_symptoms`, `hitop_measurements`, `process_metrics` | `analytics-svc` (read), `ai-pipeline-svc` (write) |
| **Feedback** | `report_feedback`, `feedback_categories`, `report_feedback_categories` | `clinical-svc` |
| **Audit & Ops** | `audit_events`, `idempotency_keys`, `outbox_events` | shared (every service writes audit) |

> Source: `docs/03_DATA_MODEL.md` §1.1.

## Cross-cutting: encryption (envelope pattern)

Every PHI column comes in **pairs**:
```sql
<field>_ciphertext      BYTEA NOT NULL,  -- AEAD-encrypted column
<field>_encrypted_dek   BYTEA NOT NULL   -- DEK wrapped by KMS KEK
```

Encrypted columns (PHI):
- `transcripts.transcript_ciphertext`
- `transcript_segments.text_ciphertext`
- `therapist_reports.report_payload_ciphertext`
- `patient_views.report_payload_ciphertext` and `patient_views.private_journal_ciphertext`
- `clinical_memory.long_term_memory_ciphertext`
- `rag_memories.summary_ciphertext`
- `hitop_measurements.evidence_ciphertext` (optional)

**Use [`pkg/cryptobox`](../../superwizor-backend/pkg/cryptobox/cryptobox.go).** API:
```go
ct, encDEK, err := crypto.Encrypt(ctx, plaintext)         // → write both columns
pt, err := crypto.Decrypt(ctx, ct, encDEK)                // → read both columns
```

Two implementations:
- `cryptobox.NewCloudKMSBox(kmsClient, kmsKeyURI)` — production
- `cryptobox.NewMockBox()` — tests + local dev when `KMS_KEY_URI` unset

KMS KEK URI in staging: in `module.kms.app_data_key_id` Terraform output.

## Cross-cutting: idempotency

Every mutating gRPC call accepts `idempotency_key` (string, ≤128 chars). Stored in `idempotency_keys` table on first request; subsequent same-key requests return the original response.

Library: [`pkg/idempotency`](../../superwizor-backend/pkg/idempotency/) (currently a stub; expand as needed).

Pipeline workers idempotency pattern:
```sql
SELECT status FROM sessions WHERE id = $1 FOR UPDATE SKIP LOCKED;
-- if status already advanced, ACK Pub/Sub without doing the work
```

## Cross-cutting: outbox pattern (ADR-DM-009)

Pub/Sub publishes are **transactional** with DB writes via the `outbox_events` table:
1. Inside the same transaction that mutates state, INSERT a row into `outbox_events`.
2. A separate poller reads `outbox_events`, publishes to Pub/Sub, marks delivered.
3. This guarantees no event is lost on DB rollback and no event is published without a corresponding state change.

> Source: `docs/03_DATA_MODEL.md` §7.5.

## Cross-cutting: auth model

Two layers everywhere:

1. **Cloud Run / Cloud Functions infrastructure layer** (Google IAM):
   - **Public services** (`identity-svc`, `clinical-svc`, `ingestion-svc`): bound `allUsers → roles/run.invoker`. Cloud Run frontend lets all requests through; the app validates Firebase tokens.
   - **Internal services** (`billing-svc`, `ai-pipeline-svc`): bound only to specific calling SAs.
   - **Cloud Functions** (`stt-worker`, `llm-worker`): triggered by Eventarc/Pub/Sub; SA bindings managed in `infra/modules/cloud-functions/`.

2. **Application layer** (Firebase ID token validation):
   - Flutter signs in to Firebase Auth → gets ID token → sends as `authorization: Bearer <token>`.
   - Service-side: validate token via Firebase Admin SDK in `identity-svc`, propagate `UserContext` in gRPC metadata to downstream services.
   - Service-to-service: callers add `Authorization: Bearer <ID_TOKEN>` from their runtime SA (Google IAM token).

> Common gotcha: `allAuthenticatedUsers` in IAM means "any Google-authenticated identity in any GCP project" — NOT "any user authenticated by your app". For Flutter-facing services, use `allUsers`.

## Cross-cutting: observability

- **Logging:** structured JSON via `slog` (stdlib). Cloud Run / Cloud Functions auto-ingest to Cloud Logging.
- **Tracing:** OpenTelemetry; init in [`pkg/observability`](../../superwizor-backend/pkg/observability/) (stub today, expand for prod). Trace propagated via gRPC metadata.
- **Metrics:** Cloud Monitoring; SLOs defined in `docs/02_*.md` §11.4 (read-only spec; not yet wired).
- **Audit:** every state mutation writes to `audit_events` (action, resource_type, resource_id, actor_id, metadata).

## Cross-cutting: error handling

Use [`pkg/errors`](../../superwizor-backend/pkg/errors/) helpers (currently stub). Map domain errors to gRPC codes:
- `codes.InvalidArgument` — validation failure (e.g., bad UUID, empty required field)
- `codes.NotFound` — resource missing
- `codes.PermissionDenied` — RBAC failure
- `codes.AlreadyExists` — idempotency conflict where the new request differs from the original
- `codes.Internal` — encryption failure, DB error, downstream service down — never leak DB error text to client

## Linting + lint enforcement

- `make lint` at repo root runs `golangci-lint` over every Go module in `go.work`.
- Default config (no `.golangci.yml`); enforced linters include errcheck, staticcheck, unused, govet.
- **Common gotchas:**
  - `defer tx.Rollback(ctx)` triggers errcheck → wrap in `defer func() { _ = tx.Rollback(ctx) }()`.
  - `cloud.google.com/go/pubsub` (v1) is deprecated → use `cloud.google.com/go/pubsub/v2`. In v2, `client.Topic(name)` becomes `client.Publisher(name)`.
  - Cloud Functions packages are `package sttworker` / `package llmworker`, NOT `package main`. The Cloud Functions framework registers entry points via `init()` calling `functions.CloudEvent(...)`. Don't add a `main()`.

## Dev environment expectations

- **gcloud:** authenticated to `superwizor-ai-25ecd`; some shell sessions need `DEVELOPER_DIR=/Library/Developer/CommandLineTools` to bypass an Xcode license shim if you're on macOS with Xcode installed.
- **Tools:** `go 1.26.2`, `buf` (proto gen), `golangci-lint`, `migrate` (golang-migrate CLI), `terragrunt`, `terraform`, `cloud-sql-proxy` (must be x86_64 on Intel Macs; arm64 on Apple Silicon).
- **Generated code:** `gen/go/<svc>/v1/*.pb.go` may be missing locally if you haven't run `buf generate proto/`. CI runs that step before lint, so local typecheck failures with "module ... does not contain package ..." are usually false alarms.

## What's deployed where (staging)

| Component | Type | Image / artifact | Notes |
|---|---|---|---|
| `api-service` | Cloud Run | `superwizor-api:<sha>` | gateway |
| `identity-svc` | Cloud Run | `superwizor-identity:<sha>` | public |
| `clinical-svc` | Cloud Run | `superwizor-clinical:<sha>` | public |
| `billing-svc` | Cloud Run | `superwizor-billing:<sha>` | internal (gRPC) |
| `ingestion-svc` | Cloud Run | `superwizor-ingestion:<sha>` | public; min=1, max=20 |
| `ai-pipeline-svc` | Cloud Run | `superwizor-ai-pipeline:<sha>` | gRPC server (workers separate) |
| `stt-worker` | Cloud Functions Gen2 | source-bundle in GCS | terraform-deployed |
| `llm-worker` | Cloud Functions Gen2 | source-bundle in GCS | terraform-deployed |
| `db-migrator` | Cloud Run Job | `superwizor-migrator:<sha>` | runs `migrate up` on every CI deploy |

## Where to look for what

| Question | File |
|---|---|
| What's the schema for table X? | `docs/03_DATA_MODEL.md` (search by table name) |
| Why was decision Y made? | ADR list above; deeper rationale in `docs/02_*.md` §1.2 / `docs/06_*.md` ADR-IMPL-* |
| How do I add a new gRPC method? | `proto/<svc>/v1/<svc>.proto` → `buf generate proto/` → implement in `services/<svc>/internal/adapters/grpc/` |
| How do I add a new DB table? | new SQL file in `migrations/` (sequential prefix); update `docs/03_*.md` §4.x |
| How do I add a new Cloud Run service? | `services/<new-svc>/` + Dockerfile + go.mod + sqlc.yaml + `internal/...`; CI workflow build+deploy steps; for a real service, also `infra/environments/staging/service-accounts.tf` |
