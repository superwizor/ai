---
description: Loads when editing CI/CD, Dockerfiles, Makefile, or workflow YAML.
globs:
  - ".github/workflows/**"
  - "**/Dockerfile"
  - "**/Dockerfile.*"
  - "superwizor-backend/Makefile"
  - "superwizor-backend/cloudbuild*.yaml"
  - "superwizor-backend/services/migrator/**"
alwaysApply: false
---

# DevOps / CI/CD

**Read [`docs/agents/07_devops-cicd.md`](../../docs/agents/07_devops-cicd.md) before editing.**

Quick orientation:

- **Single GitHub Actions workflow** at `.github/workflows/ci.yml`. Two jobs: `lint-and-test` (every push/PR) and `build-and-deploy` (push to `main` only).

- **Builds 7 images** tagged with both `${{ github.sha }}` and `:latest`: `superwizor-{migrator,api,identity,clinical,billing,ingestion,ai-pipeline}`.

- **Deploys 6 Cloud Run services + 1 Cloud Run Job** via `gcloud run deploy` / `gcloud run jobs deploy`. Image references use SHA tag (NOT `:latest`) so rollbacks work.

- **db-migrator runs BEFORE service deploys.** Schema is up before code that depends on it. Migration is idempotent (golang-migrate tracks state in `schema_migrations`).

- **Cloud Functions (`stt-worker`, `llm-worker`) are NOT in CI.** They're terraform-managed. Source is re-zipped on every `terragrunt apply`.

- **WIF (Workload Identity Federation):** `attribute_condition = assertion.repository == "superwizor/ai"`. If repo path changes, both the condition AND the `principalSet://` IAM member must update. Single terraform input: `github_repo` in `infra/environments/staging/main.tf`.

- **GitHub secrets:** `GCP_PROJECT_ID`, `GCP_WORKLOAD_IDENTITY_PROVIDER`, `GCP_SERVICE_ACCOUNT`. Job needs `permissions: { contents: read, id-token: write }`.

- **Dockerfile patterns vary by service:**
  - billing-svc: `GOWORK=off`, copies only `services/billing-svc` + `gen/`. Smallest image. `go.mod` MUST have explicit `require` for `gen/go`.
  - clinical-svc / identity-svc / ingestion-svc: copy full `services/` + `pkg/` + `gen/`; rely on `go.work`.
  - api / ai-pipeline-svc: `COPY . .` from repo root (lazy; less cache-friendly).
  - hello-world: standalone, no go.work.

- **Code in `main` is what runs in staging.** Never `gcloud run deploy` from a laptop in staging — push and let CI deploy.

- **`cloudbuild*.yaml`** files at repo root are legacy / ad-hoc — for manual `gcloud builds submit`. Don't rely on them for staging deploys.

- **Common gotchas:**
  - `unauthorized_client: rejected by attribute condition` → WIF condition mismatches actual repo path.
  - `cannot load module /app/pkg/* listed in go.work file` → Dockerfile copied `go.work` but only one service's tree. Fix: `ENV GOWORK=off` OR copy `services/` + `pkg/`.
  - `module ... gen/go provides package ... and is replaced but not required` → single-module mode + missing `require` in `go.mod`.
