---
description: Loads when editing Terraform / Terragrunt infrastructure.
globs:
  - "superwizor-backend/infra/**"
  - "**/*.tf"
  - "**/*.tfvars"
  - "**/terragrunt.hcl"
alwaysApply: false
---

# Infrastructure / Terraform

**Read [`docs/agents/08_infrastructure-terraform.md`](../../docs/agents/08_infrastructure-terraform.md) before editing.**

Quick orientation:

- **Terragrunt** for env wiring; pure terraform for modules. Backend: GCS bucket `superwizor-ai-tfstate`, prefix `environments/staging/`.

- **Project:** `superwizor-ai-25ecd`. Region: `europe-central2` (Vertex AI in `europe-west4`). Cloud SQL instance: `superwizor-db-bc4c27de`.

- **Layout:**
  - `infra/environments/staging/` — env-specific wiring (main.tf, service-accounts.tf, variables.tf, terragrunt.hcl).
  - `infra/modules/` — vpc, cloud-sql, kms, pubsub, storage, audio-storage, artifact-registry, audit-logs, cloud-functions, migrations, org-policies, wif.

- **What's terraform-managed:**
  - VPC, Cloud SQL (`superwizor-db-bc4c27de`), KMS keys (`database-key`, `app-data-key`), Pub/Sub topics + DLQs + IAM, GCS audio bucket (with OLM 48h + CMEK), Artifact Registry, Cloud Functions Gen2 (stt-worker + llm-worker), WIF pool/provider/SA, audit logs, org policies (block non-EU regions).
  - Migrations module (`module.migrations`) runs `golang-migrate` against the DB on apply.

- **What's NOT terraform-managed:**
  - **Cloud Run services** (api/identity/clinical/billing/ingestion/ai-pipeline-svc) are deployed by CI's `gcloud run deploy`. Long-term they should be `google_cloud_run_v2_service` with `lifecycle.ignore_changes = [template[0].containers[0].image]`.

- **Hard rules:**
  - **All resources in `europe-central2`** (P3). Vertex AI exception is `europe-west4`. Org policies block other regions.
  - **CMEK on PHI-touching resources** — Cloud SQL + audio bucket already use it; new resources must too.
  - **Dedicated SAs** — never bind broad roles to the default compute SA. Phase 2 has tech debt here; don't expand it.
  - **`deletion_protection = true`** on Cloud SQL — set in `module.cloud_sql/main.tf`. Don't flip without team-wide coordination.

- **Cloud SQL state notes:**
  - Name is **hardcoded** (`superwizor-db-bc4c27de`) — `random_id` was removed because it caused state drift after manual GCP changes.
  - `lifecycle.ignore_changes = [password]` on `google_sql_user.app_user` — the canonical password lives in the externally-managed `postgres-database-url` secret. Don't fight that.

- **`module.migrations`** uses `cloud-sql-proxy` locally + `migrate up` against `postgres-database-url` (NOT `superwizor-db-password`). Triggers on `migrations/*.sql` hash change. Local-only; CI uses `db-migrator` Cloud Run Job for the same purpose.

- **`module.cloud_functions`** re-zips Go source on every apply (`null_resource.package_functions.triggers.always_run = timestamp()`). Source: `services/ai-pipeline-svc/cmd/{stt-worker,llm-worker}/`.

- **WIF:** GH Actions impersonates `github-actions-sa` via OIDC. `attribute_condition = assertion.repository == "superwizor/ai"` — gates access to the SA. If you change `var.github_repo`, both the provider's condition AND the principalSet IAM member update.

- **Apply workflow (staging only — local OK for now):**
  ```bash
  cd infra/environments/staging
  terragrunt plan        # always read this carefully
  terragrunt apply
  git commit infra/...   # commit so it's reproducible
  ```

- **Common gotchas:**
  - `Failed to get existing workspaces: ... invalid_grant` → run `gcloud auth application-default login`.
  - `Bad CPU type in executable` on `cloud-sql-proxy` → wrong arch binary; download matching one.
  - `pq: password authentication failed` from migrations → stale `postgres-database-url`; reset both that secret AND the user password.
  - Cloud Function source not updating → `null_resource` triggered but zip ended up identical; tag a no-op change in source.

- **Don't:**
  - Add resources outside `europe-central2`.
  - Bypass state lock with `-lock=false`.
  - Bind `roles/owner` or `roles/editor` on a fresh SA without scoping.
  - Delete migration files that have been applied.
  - Use `random_id` for resources whose name needs to be stable across re-imports.
