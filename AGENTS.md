# Agents — Read This First

This file orients coding agents working on **SuperWizor AI**. It's a tool-agnostic fallback; the canonical Antigravity rules live in [`.antigravity/rules/`](./.antigravity/rules/) (loaded conditionally per file path), but if your agent doesn't read those, read this.

## What this product is

A clinical session co-pilot for psychotherapists in Poland. Therapist records a session in the Flutter app → audio uploaded to GCS via signed URL → STT (Chirp 3) → LLM (Gemini 2.5 PRO) generates a structured clinical report and HiTOP measurements. Polish-only, EU-resident infra, GDPR-strict.

## Required reading before any change

1. **[`docs/agents/00_GLOBAL_CONTEXT.md`](./docs/agents/00_GLOBAL_CONTEXT.md)** — non-negotiable principles (P1–P5), all ADRs, repo layout, encryption pattern, idempotency, outbox, auth model, observability conventions, dev environment. **Read this fully before doing anything.**

2. The focused per-area file in [`docs/agents/`](./docs/agents/) for the area you're touching:

| When you're editing... | Read |
|---|---|
| `superwizor-backend/services/identity-svc/**` or `proto/identity/**` | [`docs/agents/01_identity-svc.md`](./docs/agents/01_identity-svc.md) |
| `superwizor-backend/services/clinical-svc/**` or `proto/clinical/**` | [`docs/agents/02_clinical-svc.md`](./docs/agents/02_clinical-svc.md) |
| `superwizor-backend/services/billing-svc/**` or `proto/billing/**` | [`docs/agents/03_billing-svc.md`](./docs/agents/03_billing-svc.md) |
| `superwizor-backend/services/ingestion-svc/**` or `proto/ingestion/**` | [`docs/agents/04_ingestion-svc.md`](./docs/agents/04_ingestion-svc.md) |
| `superwizor-backend/services/ai-pipeline-svc/**` or `pkg/transcription/**` | [`docs/agents/05_ai-pipeline-svc.md`](./docs/agents/05_ai-pipeline-svc.md) |
| `flutter-app/**` or any `*.dart` | [`docs/agents/06_flutter-therapist-app.md`](./docs/agents/06_flutter-therapist-app.md) |
| `.github/workflows/**`, Dockerfiles, Makefile | [`docs/agents/07_devops-cicd.md`](./docs/agents/07_devops-cicd.md) |
| `superwizor-backend/infra/**` or any `*.tf` | [`docs/agents/08_infrastructure-terraform.md`](./docs/agents/08_infrastructure-terraform.md) |
| `tests/**`, `**/*_test.go`, `**/testdata/**` | [`docs/agents/09_testing.md`](./docs/agents/09_testing.md) |

3. The actual code in the repo. **When docs and code disagree, code wins.** Agent docs may lag the codebase.

## Source-of-truth ordering

1. Code in the repo (what runs)
2. Canonical Polish architecture docs: `docs/0[2,3,5,6]_*.md`
3. Curated agent docs: `docs/agents/*.md`

## Hard rules — never violate without explicit user approval

- **P1 Zero Data Loss** — idempotency at every pipeline step.
- **P2 Zero Trust** — dedicated SAs, minimum IAM.
- **P3 Iron Localization** — `europe-central2` (Vertex AI: `europe-west4`).
- **P4 Flutter is read-only on AI reports.**
- **ADR-DM-002** — PHI columns are envelope-encrypted (`*_ciphertext` + `*_encrypted_dek`). Use `pkg/cryptobox`.
- **ADR-IMPL-006** — `transcripts.transcript_ciphertext` is the canonical blob; segments are derived.
- **ADR-IMPL-002** — neutral speaker labels via `pkg/i18n/speakerlabels`; never "Therapist"/"Patient" in code or DB.

## Code conventions (compressed)

- Go 1.26.2 (`go.work`), gRPC + protobuf, sqlc for DB, golang-migrate for migrations, Pub/Sub v2 (`pubsub/v2`, `client.Publisher(name)`).
- Cloud Functions packages are `package sttworker` / `package llmworker` — **never add `func main()`**.
- `defer func() { _ = tx.Rollback(ctx) }()` (errcheck blocks bare `defer tx.Rollback(ctx)`).
- CI deploys; humans don't `gcloud run deploy` from laptops in staging. Terraform applies are local-only for staging today.

## Quick reference

| Question | Answer |
|---|---|
| GCP project | `superwizor-ai-25ecd` |
| Region | `europe-central2` |
| Cloud SQL instance | `superwizor-db-bc4c27de` |
| Database / user | `superwizor` / `superwizor_app` |
| Canonical DSN secret | `postgres-database-url` (Secret Manager) |
| KMS keyring / app key | `superwizor-keyring` / `app-data-key` |
| GitHub repo | `superwizor/ai` |
| WIF condition | `assertion.repository == "superwizor/ai"` |

## Common gotchas (real bugs we hit; don't repeat)

- `Bad CPU type in executable` on `cloud-sql-proxy` → wrong arch.
- `cloud.google.com/go/pubsub` is deprecated → use `pubsub/v2`; `client.Topic(n)` → `client.Publisher(n)`.
- `BatchRecognizeFileResult.Transcript` is deprecated → `fileResult.GetInlineResult().GetTranscript()`.
- `Unsupported operation: not supported by gRPC-web` (Flutter web) → using `.grpc(...)`; switch to `.toSingleEndpoint(...)`.
- `allAuthenticatedUsers` ≠ "users authenticated by your app" — it means "any GCP-IAM-authenticated identity". For Flutter-facing services use `allUsers`.
- `unauthorized_client: rejected by attribute condition` (CI auth) → WIF `attribute_condition` mismatches actual repo path.
- `failed to open database: pq: password authentication failed` (migrations) → stale `postgres-database-url` secret.
- `cannot load module /app/pkg/* listed in go.work file` (Docker build) → Dockerfile copied `go.work` but only one service's tree; either copy `pkg/` + all of `services/`, or `ENV GOWORK=off`.
