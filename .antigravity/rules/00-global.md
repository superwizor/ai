---
description: Project-wide invariants. Always loaded.
globs:
  - "**/*"
alwaysApply: true
---

# SuperWizor AI — Global Rules

You are working on **SuperWizor AI**, a clinical session co-pilot for psychotherapists in Poland (Polish-language only, EU-resident infrastructure, GDPR-strict).

## Read these BEFORE making any change

1. **[`docs/agents/00_GLOBAL_CONTEXT.md`](../../docs/agents/00_GLOBAL_CONTEXT.md)** — non-negotiable principles (P1–P5), ADRs (ADR-001..008, ADR-DM-001..016, ADR-IMPL-001..007), repo layout, encryption pattern, idempotency, outbox pattern, auth model, observability conventions, dev environment expectations.

2. The focused per-area file in `docs/agents/` matching the code you're editing — see the path-globbed rules in `.antigravity/rules/` for the right one.

3. The actual code in the repo. Source-of-truth ordering when docs and code disagree:
   1. Code in the repo (what runs)
   2. `docs/0[2,3,5,6]_*.md` (canonical Polish architecture docs)
   3. `docs/agents/*.md` (curated context, may lag)

## Hard constraints — NEVER violate without explicit user approval

- **P1 Zero Data Loss** — idempotency at every pipeline step; at-least-once Pub/Sub; OLM 48h backstop on audio.
- **P2 Zero Trust** — every service has a dedicated SA; default compute SA is a smell, not a target.
- **P3 Iron Localization** — all resources in `europe-central2` (Vertex AI in `europe-west4`). Org policy blocks others.
- **P4 Flutter is read-only on AI reports** — never add a write/update report endpoint reachable from mobile.
- **ADR-DM-002 Envelope encryption for PHI** — every PHI column is `<field>_ciphertext` + `<field>_encrypted_dek`. Use `pkg/cryptobox`.
- **ADR-IMPL-006 Canonical transcript blob** — `transcripts.transcript_ciphertext` is the source of truth; `transcript_segments` are derived.
- **ADR-IMPL-002 Neutral speaker labels** — never embed "Therapist"/"Patient" in code or DB; use `pkg/i18n/speakerlabels`.

## Code conventions

- **Go 1.26.2** (per `go.work`, despite ADR-003's older "1.23" mention).
- **gRPC + Protocol Buffers** for sync inter-service. `.proto` in `superwizor-backend/proto/`; generated stubs in `superwizor-backend/gen/go/` (committed; CI runs `buf generate`).
- **golang-migrate** for DB migrations in `superwizor-backend/migrations/` (sequential prefix, both `*.up.sql` and `*.down.sql`).
- **sqlc** for type-safe DB queries (`sqlc.yaml` per service).
- **Pub/Sub v2** (`cloud.google.com/go/pubsub/v2`); v1 is deprecated. `client.Publisher(name)` not `client.Topic(name)`.
- **`slog`** (stdlib) for structured logging; auto-ingested by Cloud Logging.
- **`pkg/cryptobox`** for envelope encryption — never call KMS directly.
- **`defer func() { _ = tx.Rollback(ctx) }()`** — `errcheck` blocks the bare `defer tx.Rollback(ctx)`.

## When making changes

- **Don't break the contract.** Changing a `.proto` field number, removing a gRPC method, or renaming a DB column requires coordinated client/migration updates.
- **Migrations are append-only.** Never edit a migration that's been applied. Write a new one.
- **Idempotency keys.** Every mutating gRPC call accepts `idempotency_key` (≤128 chars). Workers use `SELECT ... FOR UPDATE SKIP LOCKED` on `sessions.status`.
- **CI is the deploy path.** Don't `gcloud run deploy` from your laptop. Push to `main`, let CI deploy. Terraform applies are local-only for staging today.
- **Lint must pass.** `make lint` runs `golangci-lint` over every module in `go.work`. Default config (no `.golangci.yml`); enforced linters: errcheck, staticcheck, unused, govet.

## Common gotchas (real bugs we've hit)

- `Bad CPU type in executable` on `cloud-sql-proxy` → wrong arch binary; download the matching one.
- `cloud.google.com/go/pubsub` is deprecated → use `pubsub/v2`; `client.Topic(n)` → `client.Publisher(n)`.
- `BatchRecognizeFileResult.Transcript` is deprecated → use `fileResult.GetInlineResult().GetTranscript()`.
- Cloud Functions packages are `package sttworker` / `package llmworker`, **NOT `package main`** — never add a `main()`; the framework provides one.
- `unauthorized_client: rejected by attribute condition` from `google-github-actions/auth` → WIF `attribute_condition` doesn't match the actual GitHub repo path.
- `failed to open database: pq: password authentication failed` from migrations → the `postgres-database-url` secret has a stale password.
- `Unsupported operation: not supported by gRPC-web` (Flutter web) → using `.grpc(...)` factory; switch to `.toSingleEndpoint(...)`.
- `allAuthenticatedUsers` ≠ "users authenticated by your app" — it means "any GCP-IAM-authenticated identity". For Flutter-facing services, use `allUsers`.

## When unsure, check the per-area doc

| Area | Doc |
|---|---|
| identity-svc | `docs/agents/01_identity-svc.md` |
| clinical-svc | `docs/agents/02_clinical-svc.md` |
| billing-svc | `docs/agents/03_billing-svc.md` |
| ingestion-svc | `docs/agents/04_ingestion-svc.md` |
| ai-pipeline-svc | `docs/agents/05_ai-pipeline-svc.md` |
| Flutter therapist app | `docs/agents/06_flutter-therapist-app.md` |
| CI/CD | `docs/agents/07_devops-cicd.md` |
| Terraform / GCP | `docs/agents/08_infrastructure-terraform.md` |
| Testing (E2E, integration, unit) | `docs/agents/09_testing.md` |
| Notification service (Phase 3) | `docs/agents/10_notification-svc.md` |
