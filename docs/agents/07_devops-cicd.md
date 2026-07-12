---
type: Agent Context
title: "DevOps / CI/CD"
description: "The pipeline that takes a git push to main and turns it into a deployed staging environment. Single GitHub Actions workflow, one job, builds 7 Docker images ..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/agents/07_devops-cicd.md
tags: [agents, devops]
timestamp: 2026-05-19T16:12:12+02:00
---

# DevOps / CI/CD

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

The pipeline that takes a `git push` to `main` and turns it into a deployed staging environment. Single GitHub Actions workflow, one job, builds 7 Docker images and deploys 6 Cloud Run services + 1 Cloud Run Job.

## Status (2026-05-07)

- **CI/CD complete for all 6 Cloud Run services** + db-migrator Job (commits up to `ce7f414`).
- Cloud Functions Gen2 (`stt-worker`, `llm-worker`) are NOT in CI — they're terraform-managed.
- WIF (Workload Identity Federation) is wired and working.

## Repo paths

```
.github/workflows/ci.yml              # the single CI workflow
superwizor-backend/Makefile           # `make lint`, `make test`, `make proto`
superwizor-backend/services/<svc>/Dockerfile   # per-service build instructions
superwizor-backend/cloudbuild*.yaml   # ad-hoc Cloud Build configs (legacy; mostly unused)
infra/modules/wif/                    # terraform: WIF pool + provider + GH-actions SA
```

## The pipeline (single workflow, two jobs)

### Job 1: `lint-and-test` (runs on every push and PR)

```
checkout
setup-go (uses go.work for version pinning)
install buf + golangci-lint
buf lint proto/
buf generate proto/                    # generates gen/go/<svc>/v1/*.pb.go
make lint                              # golangci-lint over every module in go.work
make test                              # go test ./... in every module
```

### Job 2: `build-and-deploy` (runs on `push` to `main` only)

```
checkout
setup-go
install buf
buf generate proto/
google-github-actions/auth@v2          # WIF → impersonate github-actions-sa
google-github-actions/setup-gcloud@v2
gcloud auth configure-docker

# Build + push 7 images, all tagged with both ${{ github.sha }} and :latest
docker build/push: superwizor-migrator
docker build/push: superwizor-api
docker build/push: superwizor-identity
docker build/push: superwizor-clinical
docker build/push: superwizor-billing       (added in ce7f414)
docker build/push: superwizor-ingestion     (added in ce7f414)
docker build/push: superwizor-ai-pipeline   (added in ce7f414)

# Deploy + run db-migrator Cloud Run Job (idempotent: golang-migrate tracks)
gcloud run jobs deploy db-migrator
gcloud run jobs execute db-migrator --wait

# Deploy 6 Cloud Run services
gcloud run deploy api-service        --allow-unauthenticated
gcloud run deploy identity-svc       --allow-unauthenticated
gcloud run deploy clinical-svc       --allow-unauthenticated
gcloud run deploy billing-svc        --use-http2 (no public access; preserves IAM)
gcloud run deploy ingestion-svc      --allow-unauthenticated --service-account=ingestion-svc@... --min-instances=1 --max-instances=20
gcloud run deploy ai-pipeline-svc    (no public access)
```

## Image tagging

- **Primary:** `${{ github.sha }}` (40-char hex). This is what Cloud Run revisions reference.
- **Floating:** `:latest`. Kept for ad-hoc smoke tests; do NOT use for Cloud Run deploys (loses rollback capability).

ingestion-svc was previously pinned to `:latest` only — fixed in `ce7f414` so it now gets a SHA tag like everyone else.

## WIF (Workload Identity Federation)

GitHub Actions impersonates a GCP service account via OIDC, without long-lived keys.

### Topology

```
GitHub OIDC issuer (token.actions.githubusercontent.com)
  ↓ (assertion.repository == "superwizor/ai")
google_iam_workload_identity_pool: github-actions-pool
  └─ provider: github-provider
        attribute_mapping = { google.subject=assertion.sub, attribute.actor, attribute.repository }
        attribute_condition = assertion.repository == "superwizor/ai"
  ↓
google_service_account: github-actions-sa
  IAM bindings:
    roles/editor (broad — fine for staging; tighten for prod)
    roles/iam.serviceAccountUser
    roles/cloudbuild.builds.editor
    roles/artifactregistry.writer
    roles/run.admin
    roles/secretmanager.secretAccessor
  IAM principalSet binding:
    service_account_iam_member with member =
      principalSet://iam.googleapis.com/{pool}/attribute.repository/superwizor/ai
```

> When the repo moves, **both** the `attribute_condition` and the `principalSet` IAM member must update. Single terraform variable in `infra/environments/staging/main.tf`: `github_repo`.

GitHub Actions secrets used:
- `GCP_PROJECT_ID` = `superwizor-ai-25ecd`
- `GCP_WORKLOAD_IDENTITY_PROVIDER` = `module.wif.workload_identity_provider` output
- `GCP_SERVICE_ACCOUNT` = `module.wif.service_account_email` output

> Source: `infra/modules/wif/main.tf`. Recent fix in commit `ebbf1dd` (repo moved from `baciok91/superwizor-backend` to `superwizor/ai`).

## Standalone Cloud Build configs (`cloudbuild*.yaml`)

At repo root: `cloudbuild.yaml`, `cloudbuild-clinical.yaml`, `cloudbuild-identity.yaml`, `cloudbuild-ingestion.yaml`. These are **legacy / ad-hoc** — for manual `gcloud builds submit --config=...` runs. They:
- Don't tag images with commit SHA.
- Don't deploy to Cloud Run.
- Some still reference the old project ID `superwizor-staging`.

Don't rely on them. The GitHub Actions workflow is the source of truth for staging deploys. These cloudbuild files are candidates for deletion once nobody uses them.

## Cloud Functions deploy path

Cloud Functions (`stt-worker`, `llm-worker`) are NOT in the CI workflow. They're built and deployed by **terraform**:

```
infra/modules/cloud-functions/
├── main.tf                  # google_cloudfunctions2_function resources
├── package.sh               # invoked by null_resource on every apply:
│                            #   cp -R pkg/ services/ai-pipeline-svc/cmd/<worker>/
│                            #   sed `replace ../../pkg/...` → `replace ./pkg/...`
│                            #   zip everything
│                            #   upload to GCS
└── outputs.tf
```

To deploy app changes for workers:
```bash
cd infra/environments/staging
terragrunt apply -target=module.cloud_functions
```

Or just `terragrunt apply` (the `null_resource.package_functions` has `triggers = { always_run = timestamp() }` so it re-zips every apply).

> See `00_GLOBAL_CONTEXT.md` "What's deployed where" for the full inventory.

## CI patterns to keep

- **Single workflow, single job for build+deploy.** Resists the temptation to split per-service. The blast radius if any one fails is bounded.
- **Image tagging with commit SHA.** Enables rollback via `gcloud run services update --image=...:OLD_SHA`.
- **`buf generate` runs in BOTH jobs.** Lint job needs it for typecheck; build job needs it because we don't commit `gen/go/<svc>/v1/*.pb.go`. (Wait — actually the repo DOES commit gen/go; double-check before changing.)
- **`db-migrator` runs BEFORE service deploys.** Schema is up before code that depends on it.

## Anti-patterns currently present

| Issue | Impact | Fix priority |
|---|---|---|
| `services/api/Dockerfile` uses `COPY . .` from repo root | Bloated build context, no layer cache benefit | low |
| `services/ai-pipeline-svc/Dockerfile` uses `COPY . .` + `alpine:latest` runtime + no `-ldflags` | Bigger image, slower build | low |
| Some `cloudbuild-*.yaml` files reference old project ID (`superwizor-staging`) | Confusion; they're not used by CI | low — delete |
| All services use **default compute SA** for runtime (except ingestion-svc) | Over-broad permissions; can't bind narrow roles | medium — gradual fix |
| `roles/editor` on `github-actions-sa` | Too broad for prod | medium — prod should have narrow set |
| Cloud Functions deploy is NOT atomic with code deploy in CI | A push to main updates Cloud Run services first; workers update only on next `terragrunt apply` (could be later) | medium — consider `terragrunt apply -target=module.cloud_functions` as a CI step |

## Constraining principles

| What | Why |
|---|---|
| **Code in `main` is what runs in staging.** | If staging drifts from `main`, you've broken reproducibility. Always commit fixes; never `gcloud run deploy` from your laptop in staging. |
| **CI deploys; humans don't.** | Hot-fix exception only. Always commit + push + let CI deploy. |
| **Terraform applies happen from a developer machine for staging only.** | OK for now (single dev). Move to a CI job with PR approval before adding the second dev. |
| **Migrations are atomic with code deploys.** | `db-migrator` runs **before** service deploys in CI. If you split this, schema-vs-code skew is on your conscience. |

## Common gotchas

- **`unauthorized_client: rejected by attribute condition`** — WIF condition mismatches actual repo. Update `github_repo` in `infra/environments/staging/main.tf` and `terragrunt apply -target=module.wif`. Commit `ebbf1dd`.
- **`Bad CPU type in executable`** — `cloud-sql-proxy` binary at repo root is wrong arch. Download the right one for your dev machine; CI doesn't use this binary so it's a local-dev issue.
- **`module ... gen/go provides package ... and is replaced but not required`** — single-module mode (`GOWORK=off`) but `go.mod` lacks the matching `require`. Add `github.com/superwizor-ai/backend/gen/go v0.0.0-00010101000000-000000000000`. Commit `ce11f31`.
- **`cannot load module /app/pkg/* listed in go.work file`** — Dockerfile copied `go.work` but only one service's tree. Fix: either copy `pkg/` + all of `services/`, OR set `ENV GOWORK=off` and let single-module mode work. See commit `eaf7f6e`.
- **CI deploys image but service doesn't update** — usually the deploy step doesn't exist for that service. Check `.github/workflows/ci.yml` covers it.
- **GH Actions `id-token: write`** missing on the job → no OIDC token → WIF auth fails before reaching GCP.

## Local CI parity

To run what CI runs:
```bash
cd superwizor-backend
buf lint proto/
buf generate proto/
make lint                              # over every module in go.work
make test
```

For the deploy half, you'd need WIF or `gcloud auth login` with the right project — generally not worth replicating locally; just push a draft PR.

## Iteration guardrails

**Safe:**
- Add a new service (build + deploy step pair).
- Add new env vars to existing services.
- Tighten Cloud Run scaling (max-instances).
- Add new secrets via Secret Manager (terraform) and reference via `--set-secrets`.

**Careful:**
- Don't move steps between jobs without thinking about what `needs:` chains break.
- Don't change WIF inputs without `terragrunt apply` + verifying the next CI run.
- Don't switch image tagging away from SHA without a rollback story.
- Don't unilaterally change a service's `--service-account=` flag — coordinate with terraform IAM bindings.

**Don't:**
- Embed credentials/keys in workflow files (use `secrets.*` and WIF).
- Skip the `lint-and-test` job dependency on `build-and-deploy` (`needs: lint-and-test`) — that's the only thing keeping broken code out of staging.
- Run `terragrunt apply` from CI without PR approval gates (we don't yet — but if you add it, gate it).

## Runbooks

### Wiring DLQ on Eventarc subscriptions (manual post-apply)

**When to run:** after every `terragrunt apply` that touches the `cloud-functions` module, OR after any manual `gcloud functions deploy` to one of the Eventarc-driven workers (`stt-worker`, `llm-worker`, `notification-worker-on-*`).

**Why manual:** the terraform `google` / `google-beta` providers (verified up to v6.x) don't expose `dead_letter_config` on `google_cloudfunctions2_function.event_trigger`. Until they catch up, the Eventarc-managed Pub/Sub subscription must be patched out-of-band.

**The script:**
```bash
./infra/scripts/wire_dlq.sh
```
Idempotent — re-runs are no-ops. Resolves each Eventarc trigger → its auto-generated subscription, then patches `deadLetterPolicy` + `maxDeliveryAttempts`. Per-worker mapping is hard-coded in the script (keep in sync with `infra/modules/cloud-functions/main.tf`).

**Verification:**
```bash
gcloud pubsub subscriptions describe <sub-name> \
  --project=superwizor-ai-25ecd \
  --format='yaml(deadLetterPolicy)'
```
Should return a `deadLetterTopic` + `maxDeliveryAttempts` block. If empty, the patch didn't land — re-run the script.

**Symptom of forgetting to run it:** poison messages retry for the full 24h Pub/Sub retention window. Reference incident: session `b6c7a606` (2026-05-14), ~100 retries on a Chirp `INTERNAL` error, drained manually via `subscriptions seek --time=NOW`. With DLQ wired, the same message dead-letters after ~5–10 min.

## Source-doc pointers

- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §12 (CI/CD and IaC, lines 1165+) — Cloud Build / Cloud Deploy spec (canary deploys are aspirational; we use simple `gcloud run deploy` today).
- `.github/workflows/ci.yml` — the actual workflow.
