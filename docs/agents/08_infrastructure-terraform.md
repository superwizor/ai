# Infrastructure / Terraform

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

Provision and own the GCP topology: VPC, Cloud SQL, KMS, Pub/Sub, Cloud Storage, Cloud Functions Gen2 (workers), service accounts and IAM, Workload Identity Federation, audit logging, artifact registry, plus the `migrations` module that runs `golang-migrate` against the DB on apply.

**Terraform owns the boxes. CI/CD owns the contents (container images for Cloud Run services).** See architectural split in `00_GLOBAL_CONTEXT.md`.

## Status (2026-05-07)

- **Staging env (`superwizor-ai-25ecd`) — fully terraformed** for VPC, Cloud SQL, KMS, Pub/Sub topology, GCS audio bucket, artifact registry, Cloud Functions Gen2 workers, WIF, service accounts.
- **Cloud Run services** (api, identity, clinical, billing, ingestion, ai-pipeline) are NOT in terraform — created by CI's `gcloud run deploy`. Long-term these should be `google_cloud_run_v2_service` resources with `lifecycle.ignore_changes = [template[0].containers[0].image]`.
- **Migrations module** runs from a developer's machine on `terragrunt apply`. For prod this should move to a CI Cloud Run Job (already exists: `db-migrator`).

## Repo layout

```
infra/
├── environments/
│   └── staging/
│       ├── main.tf                  # module wirings
│       ├── service-accounts.tf      # ingestion-svc SA, github-actions SA token-creator bindings
│       ├── variables.tf             # project_id default = superwizor-ai-25ecd
│       ├── terragrunt.hcl           # backend (GCS), provider config
│       └── (import_*.sh, terraform.tfstate.*.backup ← legacy artifacts)
├── modules/
│   ├── vpc/                         # network + connector (swvpc-connector)
│   ├── cloud-sql/                   # superwizor-db-bc4c27de + db + user + password secret
│   ├── kms/                         # keyring + database-key + app-data-key
│   ├── pubsub/                      # 3 topics (audio.uploaded, transcript.completed, report.generated)
│   │                                # + 2 DLQ topics + debug subscription
│   ├── storage/                     # audio uploads bucket + lifecycle (OLM 48h)
│   ├── audio-storage/               # (alt path; check which is current)
│   ├── artifact-registry/           # services repo (europe-central2)
│   ├── audit-logs/                  # project-wide audit config
│   ├── cloud-functions/             # stt-worker + llm-worker + DLQ readers
│   │   ├── main.tf
│   │   └── package.sh               # zips Go source + pkg/* before upload
│   ├── migrations/                  # null_resource that runs `migrate up`
│   │   ├── main.tf
│   │   ├── run.sh                   # cloud-sql-proxy + migrate up
│   │   └── variables.tf
│   ├── org-policies/                # blocks non-EU regions
│   └── wif/                         # GH Actions WIF pool + provider + SA
```

## Stack

- **Terraform** + **Terragrunt** (terragrunt only for environment wiring; modules are pure terraform).
- **Backend:** GCS bucket `superwizor-ai-tfstate`, prefix `environments/staging/`.
- **Providers:** `hashicorp/google` 6.50, `hashicorp/google-beta` 6.50, `hashicorp/null`, `hashicorp/random`.

> If you see `Failed to get existing workspaces: ... invalid_grant ... reauth related error`, run `gcloud auth application-default login`.

## What lives where

### `module.vpc`
- `superwizor-vpc` (custom mode)
- subnet `swvpc-subnet` in europe-central2 with `enableFlowLogs`
- Serverless VPC Access connector `swvpc-connector` (used by all Cloud Run services + Cloud Functions)
- Private Service Access for Cloud SQL

### `module.cloud_sql`
- `superwizor-db-bc4c27de` (POSTGRES_16, ENTERPRISE tier `db-f1-micro` for staging)
- `deletion_protection = true`
- CMEK via `module.kms.database_key_id`
- IPv4 enabled with authorized network for local dev (`91.226.22.63/32` — update if your IP changes)
- Private network = `module.vpc.network_id`
- Database `superwizor`, user `superwizor_app`
- Password in Secret Manager `superwizor-db-password` (terraform-managed)
- `lifecycle.ignore_changes = [password]` on the user — because the canonical DSN lives in `postgres-database-url` (separate, externally managed) and we don't want terraform to fight that

### `module.kms`
- Keyring `superwizor-keyring`
- Two crypto keys: `database-key` (for Cloud SQL CMEK) and `app-data-key` (for application envelope encryption via `pkg/cryptobox`)
- Auto-rotation: 90 days

### `module.pubsub`
- Topics: `audio.uploaded`, `transcript.completed`, `report.generated`
- DLQ: `audio.uploaded.dlq`, `transcript.completed.dlq`
- Debug subscription `audio.uploaded.debug` (with `dead_letter_policy → audio.uploaded.dlq`, max_delivery_attempts=5)
- IAM: ingestion-svc → publisher on audio.uploaded; stt-worker → publisher on transcript.completed; llm-worker → publisher on report.generated

### `module.storage`
- Audio uploads bucket: `${PROJECT}-audio-uploads`
- Lifecycle: delete after 48 hours (P1 backstop)
- CMEK via `module.kms.app_data_key_id`
- IAM: ingestion-svc storage admin, stt-worker object viewer

### `module.cloud_functions`
- `stt-worker` (entry: `ProcessAudio`, runtime `go126`, 1Gi mem, 1 CPU, 540s timeout, max 10 instances)
- `llm-worker` (entry: `ProcessTranscript`, runtime `go126`, 2Gi mem, 1 CPU, 540s timeout, max 5 instances)
- Sources: `services/ai-pipeline-svc/cmd/{stt-worker,llm-worker}/`
- Eventarc triggers from Pub/Sub topics; `RETRY_POLICY_RETRY`
- DLQ subscriptions for both
- IAM bindings: speech.client (stt), aiplatform.user (llm), cloudsql.client, KMS encrypter/decrypter on app-data-key, pubsub.publisher on output topic, eventarc.eventReceiver
- **Source bundling:** `null_resource.package_functions` runs `package.sh` on every apply (`triggers = { always_run = timestamp() }`). Script copies `pkg/` flat into the cmd dir, rewrites `replace ../../pkg/...` → `replace ./pkg/...`, zips, returns the path.

### `module.migrations`
- `null_resource.run_migrations` triggered on hash of `migrations/*.sql` files
- `run.sh`:
  1. `gcloud secrets versions access latest --secret=postgres-database-url`
  2. start `cloud-sql-proxy` on port 15432
  3. `migrate -path migrations -database <local-DSN> up`
  4. kill proxy
- Reads from `postgres-database-url` (the canonical full DSN), not `superwizor-db-password`

### `module.wif`
- Pool `github-actions-pool` + provider `github-provider`
- `attribute_condition = assertion.repository == "superwizor/ai"`
- Service account `github-actions-sa` with broad staging roles (editor, run.admin, ...)
- `principalSet://...attribute.repository/superwizor/ai` IAM binding for SA impersonation

> See `07_devops-cicd.md` for how CI uses this.

### `service-accounts.tf` (in env, not module)
- `ingestion-svc@` SA + IAM (storage admin on audio bucket, secret reader, sql client, eventarc receiver)
- `pubsub_sa_*_token_creator` bindings on stt-worker/llm-worker SAs (so the Pub/Sub service agent can act as them via Eventarc)
- `data "google_project" "this"` for project number lookup

## Constraining principles

| Principle | Tech consequence |
|---|---|
| **P3 (Iron Localization)** | All resources in `europe-central2` (or `europe-west4` for Vertex AI). `module.org_policies` blocks others. Don't add resources without an explicit region. |
| **P2 (Zero Trust)** | Every service has a dedicated SA; default compute SA is a smell. Each SA has only the IAM roles it needs. |
| **CMEK for PHI** | Cloud SQL + audio bucket use CMEK from `module.kms`. Don't create new buckets/databases without CMEK. |
| **Audit logging on** | `module.audit_logs` enables ADMIN_READ + DATA_READ on all services. Don't disable. |

## Adding a new resource — checklist

1. **Where does it belong?** Module if reusable across env (vpc, kms, etc.), env-specific file if it's a single-env wiring.
2. **Region.** Specify explicitly. `europe-central2` unless there's a P3-conformant exception.
3. **CMEK.** If it touches PHI, configure encryption with `app_data_key_id`.
4. **IAM.** Use minimum role; bind to a specific SA, not `allUsers` or `allAuthenticatedUsers` (unless it's a public Cloud Run service for Flutter).
5. **Outputs.** Expose what other modules need; don't read state directly.
6. **`terragrunt plan`** locally, read it carefully.
7. **Apply** + commit.

## State management

- Backend: GCS bucket `superwizor-ai-tfstate` with object versioning + state locking.
- **Don't run `terragrunt apply` from two machines simultaneously** — state lock helps but isn't atomic for long applies (Cloud Functions zip-and-upload can take minutes).
- `terragrunt state rm` + `terragrunt import` is sometimes needed when manual GCP changes drift the state. We did this for Cloud SQL (commit history mentions `superwizor-db-4d61ad78` → `superwizor-db-bc4c27de` reconciliation).

## Migrations workflow

```bash
# Add new migration
cd superwizor-backend/migrations
migrate create -ext sql -dir . -seq new_thing
# write up + down SQL

# Test locally
cd ../infra/environments/staging
terragrunt apply -target=module.migrations
```

In CI, `db-migrator` Cloud Run Job runs `migrate up` on every push to main (before service deploys). The terraform `module.migrations` is for hands-on staging dev.

## Common gotchas

- **`Bad CPU type in executable`** when running `cloud-sql-proxy` — wrong arch (arm64 binary on Intel mac, or vice versa). Download the matching one. The `module.migrations` `run.sh` checks for this and fails loud. Local-only issue; CI uses the Cloud Run Job approach.
- **`failed to open database: pq: password authentication failed`** when migrations run — `postgres-database-url` secret is stale (different password than what's on the SQL user). Reset: get the password terraform manages from `superwizor-db-password`, then `gcloud sql users set-password superwizor_app --instance=... --password=$NEW_PW`, then `gcloud secrets versions add postgres-database-url --data-file=-` with the rebuilt DSN.
- **Cloud Function source not updating** — the `null_resource.package_functions` re-zips on every apply (`always_run=timestamp()`), but if you only changed something the trigger doesn't watch, the zip might end up identical and Cloud Functions may not redeploy. Workaround: tag a no-op change in the source dir.
- **`Module not installed`** after adding a new module → run `terragrunt init` again.
- **State drift on Cloud SQL** — the imported instance's `deletion_protection` may differ from code (we set it `true`); read the plan diff.
- **Eventarc trigger SA** needs `roles/iam.serviceAccountTokenCreator` granted to the **Pub/Sub service agent** (`service-{PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com`) ON the worker SA. Without it, Eventarc can't impersonate the worker. We have this in `service-accounts.tf`.

## Iteration guardrails

**Safe:**
- Add new Pub/Sub topics + DLQ + IAM.
- Add new buckets (with lifecycle + CMEK).
- Tighten IAM (split roles, dedicated SAs).
- Bump Cloud SQL tier.
- Add new modules.
- Edit `module.cloud_functions` to add memory/timeout/env vars to a worker.

**Careful:**
- Renaming an existing resource → state migration needed (`terragrunt state mv`).
- Changing `random_id`-generated names → already burned us once; we hard-coded `superwizor-db-bc4c27de`. If you see another `random_id`, consider locking it.
- WIF `github_repo` change → both attribute_condition AND principalSet update; CI auth breaks if either drifts.
- Cloud SQL `deletion_protection = false` → don't.
- Removing a module from main.tf without `terragrunt destroy` first → orphaned resources.

**Don't:**
- Delete production state files. (We're staging-only today; rule still holds.)
- Bypass state lock with `-lock=false`.
- Import wildly without a paired code change — state and code must agree.
- Add resources outside `europe-central2` (P3).
- Bind `roles/owner` or `roles/editor` on a fresh SA without scoping to a project. (github-actions-sa has editor today; that's a known follow-up for prod.)

## Source-doc pointers

- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §10 (Security/IAM/CMEK, lines 1051+), §11 (Observability, lines 1112+), §12 (CI/CD/IaC, lines 1165+).
- `docs/05_FAZA_1_TOZSAMOSC_DANE.md` Sprint 1.5 — observability + Cloud Monitoring.
- `docs/06_FAZA_2_INGESTION_AI.md` Sprints 2.1, 2.2, 2.4 — migration DDL, GCS, Pub/Sub.
- `infra/modules/<module>/main.tf` — actual code is the truth.
