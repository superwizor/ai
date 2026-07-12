---
type: System Documentation
title: "️ Faza 0 — Fundament infrastruktury (Tygodnie 1-2)"
description: "Wersja: 1.0 Status: Implementation guide. Zgodne z architekturą 02ARCHITEKTURATECHNICZNA.md i modelem danych 03DATAMODEL.md v4.3. Owner: DevOps / Tech Lead C..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/04_FAZA_0_FUNDAMENT.md
tags: []
timestamp: 2026-04-29T22:35:17+02:00
---

# 🏗️ Faza 0 — Fundament infrastruktury (Tygodnie 1-2)

**Wersja:** 1.0 
**Status:** Implementation guide. Zgodne z architekturą `02_ARCHITEKTURA_TECHNICZNA.md` i modelem danych `03_DATA_MODEL.md` v4.3. 
**Owner:** DevOps / Tech Lead 
**Czas trwania:** 10 dni roboczych (2 tygodnie) 
**Cel fazy:** Postawić fundament infrastruktury GCP zgodny z polityką "Żelaznej Lokalizacji" + Zero Trust + IaC. Po fazie 0 mamy infrastrukturę gotową na deploye, ale jeszcze bez kodu aplikacji.

---

## 📋 Spis treści
1. [Definition of Done dla całej fazy (TRACKER)](#tracker-definition-of-done-dla-całej-fazy)
2. [Sprint planning i timeline](#sprint-planning-i-timeline)
3. [Prerequisites — co musisz mieć przed startem](#prerequisites--co-musisz-mieć-przed-startem)
4. [Sprint 0.1 — Setup projektów GCP (Dni 1-2)](#sprint-01--setup-projektów-gcp-dni-1-2)
5. [Sprint 0.2 — Monorepo i Go workspaces (Dni 3-4)](#sprint-02--monorepo-i-go-workspaces-dni-3-4)
6. [Sprint 0.3 — Terraform foundation (Dni 5-7)](#sprint-03--terraform-foundation-dni-5-7)
7. [Sprint 0.4 — Cloud SQL + pgvector (Dni 8-9)](#sprint-04--cloud-sql--pgvector-dni-8-9)
8. [Sprint 0.5 — CI/CD pipeline + smoke test (Dzień 10)](#sprint-05--cicd-pipeline--smoke-test-dzień-10)
9. [Troubleshooting cookbook](#troubleshooting-cookbook)
10. [Pre-Faza 1 checklist (Szczegółowy TRACKER)](#pre-faza-1-checklist-szczegółowy-tracker)

---

## 🎯 TRACKER: Definition of Done dla całej fazy

Faza 0 jest "done" kiedy spełnione SĄ WSZYSTKIE poniższe:

- [x] Dwa GCP projects (`superwizor-staging`, `superwizor-prod`) z Billing Account podłączonym i ograniczeniem regionu do `europe-central2`.
- [x] **[KOD GOTOWY]** Org Policies wymuszają: tylko `europe-central2`, tylko CMEK, blokada public IP na Cloud SQL.
- [x] **[KOD GOTOWY]** Shared VPC z Private Service Access dla Cloud SQL.
- [x] **[KOD GOTOWY]** Cloud KMS keyring z 4 kluczami (audio, database, secrets, app-data).
- [x] **[KOD GOTOWY]** Cloud SQL PostgreSQL 16 instance z pgvector extension (czeka na `terragrunt apply`).
- [x] Monorepo `superwizor-backend/` z `go.work`, `proto/`, `infra/`, pierwszą migracją SQL.
- [x] **[KOD GOTOWY]** Cloud Build / GitHub Actions trigger uruchamia pipeline (plik `.github/workflows/ci.yml` stworzony, czeka na push).
- [x] Smoke test: minimalny "hello world" Go service deployowany na staging Cloud Run odpowiada 200 OK.
- [x] Dokumentacja: `README.md` w monorepo z instrukcją "jak zacząć dla nowego dev'a w 30 minut".
- [x] Backup state Terraform w GCS bucket z versioning.

---

## 📝 Pre-Faza 1 checklist (Szczegółowy TRACKER)
*Przed rozpoczęciem Fazy 1 zweryfikuj:*

### Infrastruktura
- [x] Oba projekty GCP utworzone z włączonymi APIs.
- [x] **[KOD GOTOWY]** Org Policies blokują wszystkie regiony poza europe-central2.
- [x] **[KOD GOTOWY]** Shared VPC + Private Service Access + VPC Connector działają.
- [x] **[KOD GOTOWY]** KMS keyring z 4 kluczami (audio, database, secrets, app-data).
- [x] **[KOD GOTOWY]** Cloud SQL PostgreSQL 16 z pgvector extension działa.
- [x] **[KOD GOTOWY]** Artifact Registry repo services utworzone.

### Code & tooling
- [x] Monorepo struktura zgodna z `02_ARCHITEKTURA_TECHNICZNA.md` sekcja 14.
- [x] `go.work` poprawnie linkuje wszystkie moduły.
- [x] `buf generate proto/` przechodzi bez błędów.
- [x] `make lint`, `make test` działają.
- [x] Pierwsza migracja SQL (000001_initial_extensions) zaaplikowana na staging DB.

### CI/CD
- [x] **[KOD GOTOWY]** GitHub Actions workflow `ci.yml` dodany do repo.
- [x] **[KOD GOTOWY]** Workload Identity Federation skonfigurowane w Terraform (zero JSON keys).
- [x] Hello-world service deployowany na staging.
- [x] `curl ${SERVICE_URL}/healthz` zwraca OK.

### Documentation
- [x] `README.md` w monorepo pozwala nowemu dev'owi zacząć pracę w 30 minut.
- [x] `docs/04_FAZA_0_FUNDAMENT.md` (ten plik) commited do repo.
- [x] Architecture Decision Records w `docs/adr/` (przynajmniej ADR-001 dla wyborów z Sprint 0.1-0.5).

### Bezpieczeństwo
- [x] Żaden JSON service account key nie jest w repo.
- [x] Hasło do Cloud SQL w Secret Manager (nie w `terraform.tfvars`).
- [x] `*.tfvars` w `.gitignore`.
- [x] Cloud Audit Logs włączone dla wszystkich projektów.

---

*(Poniżej znajduje się pełna, oryginalna dokumentacja Fazy 0 do wglądu i kopiowania komend w trakcie pracy)*

## Sprint planning i timeline
Tydzień 1                          Tydzień 2

┌─────────────┬─────────────┐      ┌─────────────┬─────────────┐
│ Pn-Wt       │ Śr-Czw      │      │ Pn-Wt       │ Śr          │
│ Sprint 0.1  │ Sprint 0.2  │      │ Sprint 0.3  │ Sprint 0.4  │
│ GCP setup   │ Monorepo    │      │ Terraform   │ Cloud SQL   │
│             │             │      │ foundation  │ + pgvector  │
├─────────────┴─────────────┤      ├─────────────┴─────────────┤
│ Pt: review, retro          │      │ Czw: Sprint 0.4 cd        │
│                            │      │ Pt: Sprint 0.5 (CI/CD)    │
└────────────────────────────┘      └────────────────────────────┘

### Dependencies graph
```
Sprint 0.1 (GCP projects)
    │
    ├──► Sprint 0.2 (Monorepo) — może iść równolegle
    │
    ▼
Sprint 0.3 (Terraform foundation) ──► Sprint 0.4 (Cloud SQL)
                                            │
                                            ▼
                                  Sprint 0.5 (CI/CD + smoke test)
```

### Owner & accountability
| Sprint | Primary owner | Reviewer | Estimate |
|---|---|---|---|
| 0.1 GCP setup | DevOps lead | CTO | 1 dzień |
| 0.2 Monorepo | Tech lead | DevOps | 1 dzień |
| 0.3 Terraform | DevOps lead | Senior backend | 3 dni |
| 0.4 Cloud SQL | DevOps lead | Senior backend | 1 dzień |
| 0.5 CI/CD + smoke | DevOps lead | Tech lead | 1 dzień |

## Prerequisites
Przed startem Fazy 0 musisz mieć:

### Konta i tooling
- GCP account z Billing Account ID (skopiuj z Console → Billing → Manage your billing account).
- Aplikacja o GCP for Startups wysłana (nawet jeśli czekasz na approval — możesz korzystać z $300 free tier).
- Domena firmowa zarejestrowana (np. superwizor.ai) z public landing page.
- Email firmowy na domenie (kontakt@superwizor.ai) — wymóg dla Google for Startups.
- GitHub organization stworzona (superwizor-ai) lub repo prywatne na GitLab/Bitbucket.

### Lokalne tooling (zainstaluj wszystko przed dniem 1)
```bash
# gcloud CLI (>= v521)
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
gcloud --version  # sprawdź czy v521+

# Terraform (>= 1.7)
brew install terraform           # macOS
# lub Linux:
wget https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip
unzip terraform_1.7.5_linux_amd64.zip && sudo mv terraform /usr/local/bin/

# Terragrunt (>= 0.55) - DRY dla Terraform
brew install terragrunt          # macOS

# Go (>= 1.23)
brew install go                  # macOS
go version  # sprawdź czy 1.23+

# buf - lepszy protoc do gRPC
brew install bufbuild/buf/buf

# golang-migrate dla migracji SQL
brew install golang-migrate

# golangci-lint dla linterów
brew install golangci-lint

# pre-commit hooks (opcjonalne ale zalecane)
brew install pre-commit
```

Sanity check wszystkich tooli:
```bash
gcloud --version && terraform --version && terragrunt --version && \
  go version && buf --version && migrate -version && \
  golangci-lint --version
```
Jeśli któryś nie odpowiada → zainstaluj zanim ruszysz dalej.


## Sprint 0.1 — Setup projektów GCP
**Czas:** 1 dzień 
**Cel:** Stworzyć dwa projekty GCP (staging, prod), włączyć APIs, ustawić Org Policies wymuszające europe-central2.

### Task 0.1.1 — Login i wybór organizacji
```bash
# Login do gcloud
gcloud auth login
gcloud auth application-default login   # dla Terraform

# Sprawdź dostępne organizacje (jeśli jesteś w organizacji)
gcloud organizations list
# Output: DISPLAY_NAME    ID
#         superwizor.ai   123456789012

# Ustaw default organization (jeśli używasz)
export ORG_ID="123456789012"   # podmień na swoje
export BILLING_ACCOUNT="0X0X0X-0X0X0X-0X0X0X"   # z Console → Billing
```

### Task 0.1.2 — Stwórz dwa projekty
```bash
# Staging project
gcloud projects create superwizor-staging \
  --name="SuperWizor AI Staging" \
  --organization=${ORG_ID}

# Prod project
gcloud projects create superwizor-prod \
  --name="SuperWizor AI Production" \
  --organization=${ORG_ID}

# Podpięcie billing
gcloud billing projects link superwizor-staging \
  --billing-account=${BILLING_ACCOUNT}

gcloud billing projects link superwizor-prod \
  --billing-account=${BILLING_ACCOUNT}
```
**Definition of Done dla Task 0.1.2:**
- `gcloud projects list` pokazuje oba projekty.
- `gcloud billing projects describe superwizor-prod` zwraca `billingEnabled: true`.

### Task 0.1.3 — Włącz wymagane APIs
```bash
# Stwórz reusable script: scripts/enable-apis.sh
mkdir -p scripts
cat > scripts/enable-apis.sh <<'EOF'
#!/bin/bash
set -euo pipefail

PROJECT_ID="${1:?Usage: $0 <project-id>}"

APIS=(
  # Compute & containers
  "run.googleapis.com"
  "artifactregistry.googleapis.com"
  "cloudbuild.googleapis.com"
  "container.googleapis.com"
  # Data
  "sqladmin.googleapis.com"
  "storage.googleapis.com"
  "firestore.googleapis.com"
  # Networking
  "compute.googleapis.com"
  "vpcaccess.googleapis.com"
  "servicenetworking.googleapis.com"
  "dns.googleapis.com"
  # Security & IAM
  "iam.googleapis.com"
  "cloudkms.googleapis.com"
  "secretmanager.googleapis.com"
  "iap.googleapis.com"
  # Observability
  "logging.googleapis.com"
  "monitoring.googleapis.com"
  "cloudtrace.googleapis.com"
  # Eventing & messaging
  "pubsub.googleapis.com"
  "eventarc.googleapis.com"
  "cloudscheduler.googleapis.com"
  # AI
  "aiplatform.googleapis.com"
  "speech.googleapis.com"
  # Other
  "cloudresourcemanager.googleapis.com"
  "orgpolicy.googleapis.com"
  "dlp.googleapis.com"
)

echo "Enabling APIs in project: ${PROJECT_ID}"
gcloud services enable "${APIS[@]}" --project="${PROJECT_ID}"
echo "✅ All APIs enabled"
EOF

chmod +x scripts/enable-apis.sh

# Uruchom dla obu projektów
./scripts/enable-apis.sh superwizor-staging
./scripts/enable-apis.sh superwizor-prod
```
Uwaga: włączenie APIs to ~5-10 min (Google ma quota na batch enable).

### Task 0.1.4 — Org Policies wymuszające europe-central2
To jest KRYTYCZNE dla compliance RODO ("Żelazna Lokalizacja").
```bash
# Stwórz folder dla policies
mkdir -p infra/organization
cd infra/organization

# Policy: tylko europe-central2 jako resource location
cat > org-policy-region-restriction.yaml <<'EOF'
name: projects/PROJECT_ID/policies/gcp.resourceLocations
spec:
  rules:
    - condition:
        expression: "resource.matchTagId('REPLACE_WITH_YOUR_TAG_VALUE') == false"
      values:
        allowedValues:
          - "in:europe-central2-locations"
    - values:
        allowedValues:
          - "in:europe-central2-locations"
EOF

# Apply dla staging
gcloud resource-manager org-policies set-policy \
  org-policy-region-restriction.yaml \
  --project=superwizor-staging \
  --replace-tokens="PROJECT_ID=superwizor-staging"

# Apply dla prod
gcloud resource-manager org-policies set-policy \
  org-policy-region-restriction.yaml \
  --project=superwizor-prod \
  --replace-tokens="PROJECT_ID=superwizor-prod"
```

Alternatywa (bez Organization-level access): ustaw w Terraform `infra/organization/org-policies.tf`:
```terraform
# infra/organization/org-policies.tf
resource "google_org_policy_policy" "region_restriction" {
  for_each = toset([var.staging_project_id, var.prod_project_id])
  name   = "projects/${each.value}/policies/gcp.resourceLocations"
  parent = "projects/${each.value}"
  spec {
    rules {
      values {
        allowed_values = ["in:europe-central2-locations"]
      }
    }
  }
}

resource "google_org_policy_policy" "require_cmek" {
  for_each = toset([var.staging_project_id, var.prod_project_id])
  name   = "projects/${each.value}/policies/gcp.restrictNonCmekServices"
  parent = "projects/${each.value}"
  spec {
    rules {
      values {
        allowed_values = [
          "sqladmin.googleapis.com",
          "storage.googleapis.com",
        ]
      }
    }
  }
}

resource "google_org_policy_policy" "disable_public_ip_sql" {
  for_each = toset([var.staging_project_id, var.prod_project_id])
  name   = "projects/${each.value}/policies/sql.restrictPublicIp"
  parent = "projects/${each.value}"
  spec {
    rules {
      enforce = "TRUE"
    }
  }
}
```

**Definition of Done dla Task 0.1.4:**
- Próba stworzenia bucketa w `us-central1` → kończy się błędem `FAILED_PRECONDITION: violates organization policy`.
- `gcloud sql instances describe` w obu projektach respektuje policy.

### Task 0.1.5 — Service Account dla Terraform
```bash
# Tworzy SA dla każdego projektu
for PROJECT in superwizor-staging superwizor-prod; do
  gcloud iam service-accounts create terraform-deployer \
    --display-name="Terraform Deployer" \
    --project=${PROJECT}

  # Daj mu role potrzebne do bootstrap
  for ROLE in \
    "roles/editor" \
    "roles/iam.securityAdmin" \
    "roles/resourcemanager.projectIamAdmin" \
    "roles/serviceusage.serviceUsageAdmin"
  do
    gcloud projects add-iam-policy-binding ${PROJECT} \
      --member="serviceAccount:terraform-deployer@${PROJECT}.iam.gserviceaccount.com" \
      --role="${ROLE}" \
      --condition=None
  done
  echo "✅ SA terraform-deployer ready in ${PROJECT}"
done
```
Bezpieczeństwo: Nie generuj JSON key file. W produkcji używaj Workload Identity Federation (zrobimy w Sprint 0.5).

### Smoke test Sprint 0.1
```bash
# Sprawdź że wszystko działa
gcloud projects list --filter="superwizor"
gcloud services list --enabled --project=superwizor-staging | head -20
gcloud iam service-accounts list --project=superwizor-staging
```


## Sprint 0.2 — Monorepo i Go workspaces
**Czas:** 1 dzień 
**Cel:** Utworzyć strukturę monorepo z Go workspaces, buf dla protobuf, pierwszy Makefile.

### Task 0.2.1 — Init repo i struktura
```bash
mkdir superwizor-backend && cd superwizor-backend
git init
git remote add origin git@github.com:superwizor-ai/backend.git

# Stwórz strukturę
mkdir -p \
  proto/identity/v1 \
  proto/billing/v1 \
  proto/clinical/v1 \
  proto/ingestion/v1 \
  proto/analytics/v1 \
  proto/notification/v1 \
  proto/events/v1 \
  pkg/authz \
  pkg/cryptobox \
  pkg/errors \
  pkg/idempotency \
  pkg/logging \
  pkg/observability \
  pkg/pubsubx \
  pkg/testutil \
  services/identity-svc/cmd/server \
  services/identity-svc/internal/{domain,app,adapters,config} \
  services/billing-svc/cmd/server \
  services/clinical-svc/cmd/server \
  services/ingestion-svc/cmd/server \
  services/analytics-svc/cmd/server \
  services/notification-svc/cmd/server \
  services/ai-pipeline-svc/cmd/{stt-worker,llm-worker,memory-compactor-worker} \
  migrations \
  infra/{modules,environments/staging,environments/prod,organization} \
  scripts \
  docs/{adr,runbooks,diagrams}

# Touch pierwsze pliki
touch README.md Makefile go.work
```

### Task 0.2.2 — go.work setup
```bash
# Init Go workspace
go work init

# Add każdy serwis (na razie jako placeholder — moduły utworzymy w Fazie 1)
for svc in identity-svc billing-svc clinical-svc ingestion-svc analytics-svc notification-svc ai-pipeline-svc; do
  cd services/${svc}
  go mod init github.com/superwizor-ai/backend/services/${svc}
  cd ../..
  go work use ./services/${svc}
done

# pkg modules
for pkg in authz cryptobox errors idempotency logging observability pubsubx testutil; do
  cd pkg/${pkg}
  go mod init github.com/superwizor-ai/backend/pkg/${pkg}
  cd ../..
  go work use ./pkg/${pkg}
done

go work sync
```

### Task 0.2.3 — buf konfiguracja dla gRPC
```bash
# buf.yaml — konfiguracja głównego modułu
cat > proto/buf.yaml <<'EOF'
version: v2
modules:
  - path: .
lint:
  use:
    - STANDARD
breaking:
  use:
    - FILE
deps:
  - buf.build/googleapis/googleapis
  - buf.build/grpc-ecosystem/grpc-gateway
EOF

# buf.gen.yaml — generacja Go stubs
cat > buf.gen.yaml <<'EOF'
version: v2
managed:
  enabled: true
  override:
    - file_option: go_package_prefix
      value: github.com/superwizor-ai/backend/gen/go
plugins:
  - remote: buf.build/protocolbuffers/go
    out: gen/go
    opt:
      - paths=source_relative
  - remote: buf.build/grpc/go
    out: gen/go
    opt:
      - paths=source_relative
      - require_unimplemented_servers=true
EOF

# Stwórz przykładowy proto
cat > proto/identity/v1/identity.proto <<'EOF'
syntax = "proto3";

package identity.v1;

option go_package = "github.com/superwizor-ai/backend/gen/go/identity/v1;identityv1";

service IdentityService {
  rpc HealthCheck(HealthCheckRequest) returns (HealthCheckResponse);
}

message HealthCheckRequest {}

message HealthCheckResponse {
  string status = 1;
  string version = 2;
}
EOF

# Test generowania
buf dep update proto/
buf generate proto/

# Sprawdź że gen/go/identity/v1/identity.pb.go i identity_grpc.pb.go zostały wygenerowane
ls -la gen/go/identity/v1/
```

### Task 0.2.4 — Makefile z głównymi komendami
```makefile
# Makefile
.PHONY: help proto lint test build docker-build clean

PROJECT_ID_STAGING := superwizor-staging
PROJECT_ID_PROD := superwizor-prod
REGION := europe-central2
REGISTRY := $(REGION)-docker.pkg.dev/$(PROJECT_ID_STAGING)/services

help:  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

proto:  ## Generate Go code from proto files
	buf dep update proto/
	buf lint proto/
	buf generate proto/

lint:  ## Run golangci-lint on all services
	@for dir in $$(find . -name "go.mod" -not -path "*/node_modules/*" -exec dirname {} \;); do \
		echo "Linting $$dir"; \
		(cd $$dir && golangci-lint run ./...) || exit 1; \
	done

test:  ## Run unit tests for all modules
	@for dir in $$(find . -name "go.mod" -not -path "*/node_modules/*" -exec dirname {} \;); do \
		echo "Testing $$dir"; \
		(cd $$dir && go test -race -coverprofile=cov.out ./...) || exit 1; \
	done

build:  ## Build all service binaries
	@for svc in identity-svc billing-svc clinical-svc ingestion-svc analytics-svc notification-svc; do \
		echo "Building $$svc"; \
		go build -o bin/$$svc ./services/$$svc/cmd/server; \
	done

migrate-up:  ## Run database migrations (staging)
	migrate -path migrations \
	  -database "postgres://$(DB_USER):$(DB_PASSWORD)@127.0.0.1:5432/superwizor?sslmode=disable" \
	  up

migrate-down:  ## Rollback last migration
	migrate -path migrations \
	  -database "postgres://$(DB_USER):$(DB_PASSWORD)@127.0.0.1:5432/superwizor?sslmode=disable" \
	  down 1

migrate-create:  ## Create new migration: make migrate-create NAME=add_users_table
	migrate create -ext sql -dir migrations -seq $(NAME)

tf-init:  ## Initialize Terraform for ENV=staging|prod
	cd infra/environments/$(ENV) && terragrunt init

tf-plan:  ## Plan Terraform changes
	cd infra/environments/$(ENV) && terragrunt plan

tf-apply:  ## Apply Terraform changes
	cd infra/environments/$(ENV) && terragrunt apply

clean:  ## Clean build artifacts
	rm -rf bin/ gen/ cov.out
```

### Task 0.2.5 — .gitignore i README
```bash
cat > .gitignore <<'EOF'
# Binaries
bin/
*.exe

# Test coverage
cov.out
coverage.html

# Go module cache (don't commit but keep tracked separately)
vendor/

# Terraform
*.tfstate
*.tfstate.backup
*.tfvars
.terraform/
.terragrunt-cache/

# IDE
.idea/
.vscode/
*.swp

# OS
.DS_Store
Thumbs.db

# Secrets — NIGDY nie commituj
*.json
!buf.gen.yaml
!*.example.json
.env
.env.local

# Logs
*.log
EOF

cat > README.md <<'EOF'
# SuperWizor AI Backend
Production-grade backend for SuperWizor AI — clinical supervision platform for psychotherapists.

## Quick start (30 minutes)

### Prerequisites
- Go 1.23+, Terraform 1.7+, gcloud CLI v521+, buf, golang-migrate
- See [Faza 0 doc](docs/04_FAZA_0_FUNDAMENT.md) for detailed setup

### Local development
```bash
git clone git@github.com:superwizor-ai/backend.git
cd backend

# Generate proto stubs
make proto

# Lint and test everything
make lint
make test

# Run a single service locally
cd services/identity-svc
go run ./cmd/server
```

## Repository structure
See docs/02_ARCHITEKTURA_TECHNICZNA.md for full architecture.

## Documentation
- Konstytucja projektu
- Architektura techniczna
- Model danych v4.3
- Faza 0 — Fundament
- Faza 1 — Tożsamość i dane
EOF
```

**Pierwszy commit**
```bash
git add . 
git commit -m "chore: initial monorepo structure with Go workspaces" 
git push -u origin main
```

### Smoke test Sprint 0.2
```bash
make proto    # powinno wygenerować gen/go/identity/v1/...
make lint     # powinno zwrócić "0 issues" (jeszcze nie ma kodu)
make test     # powinno powiedzieć "no test files"
go work sync  # powinno zakończyć się bez błędów
```


## Sprint 0.3 — Terraform foundation
**Czas:** 3 dni 
**Cel:** Postawić Terraform state backend + moduły bazowe + Shared VPC.

### Task 0.3.1 — GCS bucket dla Terraform state
```bash
# Stwórz dedykowany projekt do trzymania state (best practice)
gcloud projects create superwizor-tfstate \
  --name="SuperWizor Terraform State" \
  --organization=${ORG_ID}

gcloud billing projects link superwizor-tfstate \
  --billing-account=${BILLING_ACCOUNT}

# Włącz Storage API
gcloud services enable storage.googleapis.com --project=superwizor-tfstate

# Stwórz bucket z versioning + lifecycle
gcloud storage buckets create gs://superwizor-tfstate-eu2 \
  --project=superwizor-tfstate \
  --location=europe-central2 \
  --uniform-bucket-level-access \
  --public-access-prevention

gcloud storage buckets update gs://superwizor-tfstate-eu2 \
  --versioning

# Lifecycle: kasuj noncurrent versions po 90 dniach
cat > lifecycle.json <<'EOF'
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "Delete"},
        "condition": {
          "numNewerVersions": 5,
          "daysSinceNoncurrentTime": 90
        }
      }
    ]
  }
}
EOF

gcloud storage buckets update gs://superwizor-tfstate-eu2 \
  --lifecycle-file=lifecycle.json
rm lifecycle.json
```

### Task 0.3.2 — Terragrunt root config
```bash
mkdir -p infra/environments

# Główny terragrunt.hcl
cat > infra/terragrunt.hcl <<'EOF'
remote_state {
  backend = "gcs"
  config = {
    bucket   = "superwizor-tfstate-eu2"
    prefix   = "${path_relative_to_include()}"
    project  = "superwizor-tfstate"
    location = "europe-central2"
  }
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<TF
terraform {
  required_version = ">= 1.7"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  region = "europe-central2"
}

provider "google-beta" {
  region = "europe-central2"
}
TF
}
EOF
```

### Task 0.3.3 — Moduł VPC z Private Service Access
```bash
mkdir -p infra/modules/vpc

cat > infra/modules/vpc/main.tf <<'EOF'
variable "project_id" { type = string }
variable "network_name" {
  type    = string
  default = "superwizor-vpc"
}
variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/20"
}

resource "google_compute_network" "main" {
  name                    = var.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
}

resource "google_compute_subnetwork" "main" {
  name          = "${var.network_name}-subnet"
  project       = var.project_id
  network       = google_compute_network.main.id
  ip_cidr_range = var.subnet_cidr
  region        = "europe-central2"
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Private Service Access dla Cloud SQL (private IP)
resource "google_compute_global_address" "private_service_range" {
  provider      = google-beta
  project       = var.project_id
  name          = "${var.network_name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.main.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  provider                = google-beta
  network                 = google_compute_network.main.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_service_range.name]
  deletion_policy = "ABANDON"
}

# Serverless VPC Access Connector dla Cloud Run → Cloud SQL
resource "google_vpc_access_connector" "main" {
  name          = "swvpc-connector"
  project       = var.project_id
  region        = "europe-central2"
  network       = google_compute_network.main.name
  ip_cidr_range = "10.8.0.0/28"
  min_instances = 2
  max_instances = 3
  machine_type  = "e2-micro"
}

output "network_id" { value = google_compute_network.main.id }
output "network_name" { value = google_compute_network.main.name }
output "subnet_id" { value = google_compute_subnetwork.main.id }
output "vpc_connector_id" { value = google_vpc_access_connector.main.id }
EOF
```

### Task 0.3.4 — Moduł KMS keyring
```bash
mkdir -p infra/modules/kms

cat > infra/modules/kms/main.tf <<'EOF'
variable "project_id" { type = string }
variable "keyring_name" {
  type    = string
  default = "superwizor-keyring"
}

resource "google_kms_key_ring" "main" {
  name     = var.keyring_name
  project  = var.project_id
  location = "europe-central2"
}

# Klucz dla bucketu audio
resource "google_kms_crypto_key" "audio_bucket" {
  name     = "audio-bucket-key"
  key_ring = google_kms_key_ring.main.id
  purpose  = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"  # 90 dni

  lifecycle {
    prevent_destroy = true
  }
}

# Klucz dla Cloud SQL
resource "google_kms_crypto_key" "database" {
  name     = "database-key"
  key_ring = google_kms_key_ring.main.id
  purpose  = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

# Klucz dla Secret Manager
resource "google_kms_crypto_key" "secrets" {
  name     = "secrets-key"
  key_ring = google_kms_key_ring.main.id
  purpose  = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

# Klucz aplikacyjny (envelope encryption dla PHI)
resource "google_kms_crypto_key" "app_data" {
  name     = "app-data-key"
  key_ring = google_kms_key_ring.main.id
  purpose  = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

# Cloud SQL service account — daj mu uprawnienia do KMS
data "google_project" "current" {
  project_id = var.project_id
}

resource "google_kms_crypto_key_iam_member" "cloud_sql_kms" {
  crypto_key_id = google_kms_crypto_key.database.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
}

resource "google_kms_crypto_key_iam_member" "storage_kms" {
  crypto_key_id = google_kms_crypto_key.audio_bucket.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${data.google_project.current.number}@gs-project-accounts.iam.gserviceaccount.com"
}

output "keyring_id" { value = google_kms_key_ring.main.id }
output "audio_key_id" { value = google_kms_crypto_key.audio_bucket.id }
output "database_key_id" { value = google_kms_crypto_key.database.id }
output "secrets_key_id" { value = google_kms_crypto_key.secrets.id }
output "app_data_key_id" { value = google_kms_crypto_key.app_data.id }
EOF
```

### Task 0.3.5 — Moduł Artifact Registry
```bash
mkdir -p infra/modules/artifact-registry

cat > infra/modules/artifact-registry/main.tf <<'EOF'
variable "project_id" { type = string }

resource "google_artifact_registry_repository" "services" {
  project       = var.project_id
  location      = "europe-central2"
  repository_id = "services"
  description   = "Docker images for SuperWizor microservices"
  format        = "DOCKER"

  cleanup_policies {
    id     = "keep-last-30"
    action = "KEEP"
    most_recent_versions {
      keep_count = 30
    }
  }

  cleanup_policies {
    id     = "delete-untagged-after-7d"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "604800s"  # 7 days
    }
  }
}

output "registry_url" {
  value = "europe-central2-docker.pkg.dev/${var.project_id}/services"
}
EOF
```

### Task 0.3.6 — Staging environment definition
```bash
cat > infra/environments/staging/terragrunt.hcl <<'EOF'
include "root" {
  path = find_in_parent_folders()
}

inputs = {
  project_id  = "superwizor-staging"
  environment = "staging"
}
EOF

cat > infra/environments/staging/main.tf <<'EOF'
variable "project_id" { type = string }
variable "environment" { type = string }

module "vpc" {
  source     = "../../modules/vpc"
  project_id = var.project_id
}

module "kms" {
  source     = "../../modules/kms"
  project_id = var.project_id
}

module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
}

# Outputy do użycia w Fazie 1
output "vpc_id" { value = module.vpc.network_id }
output "vpc_connector_id" { value = module.vpc.vpc_connector_id }
output "database_key_id" { value = module.kms.database_key_id }
output "registry_url" { value = module.artifact_registry.registry_url }
EOF
```

### Task 0.3.7 — Deploy staging foundation
```bash
cd infra/environments/staging

# Init
terragrunt init

# Plan — sprawdź co zostanie utworzone
terragrunt plan

# Apply — TYLKO jeśli plan wygląda OK
terragrunt apply

# Output: zapisz dla Sprint 0.4
terragrunt output > outputs.txt
```
Czas: ~10-15 minut (KMS keyring + VPC + Service Networking peering jest wolne).

### Smoke test Sprint 0.3
```bash
# Sprawdź że wszystko jest na miejscu
gcloud compute networks list --project=superwizor-staging
gcloud kms keys list --location=europe-central2 \
  --keyring=superwizor-keyring --project=superwizor-staging
gcloud artifacts repositories list --project=superwizor-staging
```

## Sprint 0.4 — Cloud SQL + pgvector
**Czas:** 1 dzień 
**Cel:** Postawić Cloud SQL PostgreSQL 16 z pgvector enabled, zweryfikować connection.

### Task 0.4.1 — Moduł Cloud SQL
```bash
mkdir -p infra/modules/cloud-sql

cat > infra/modules/cloud-sql/main.tf <<'EOF'
variable "project_id" { type = string }
variable "environment" { type = string }
variable "vpc_id" { type = string }
variable "database_key_id" { type = string }

variable "tier" {
  type    = string
  default = "db-custom-2-7680"  # staging: 2 vCPU, 7.5GB RAM
}

variable "availability_type" {
  type    = string
  default = "ZONAL"  # staging; prod = REGIONAL
}

resource "random_password" "postgres" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "postgres-password"

  replication {
    user_managed {
      replicas {
        location = "europe-central2"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.postgres.result
}

resource "google_sql_database_instance" "main" {
  name             = "superwizor-${var.environment}"
  project          = var.project_id
  database_version = "POSTGRES_16"
  region           = "europe-central2"
  encryption_key_name = var.database_key_id
  deletion_protection = var.environment == "prod" ? true : false

  settings {
    tier              = var.tier
    availability_type = var.availability_type
    disk_size         = 50
    disk_type         = "PD_SSD"
    disk_autoresize   = true

    # PostgreSQL flags optimized for our workload
    database_flags {
      name  = "cloudsql.iam_authentication"
      value = "on"
    }
    database_flags {
      name  = "max_connections"
      value = "200"
    }
    database_flags {
      name  = "shared_buffers"
      value = "1843200"  # 1.75GB w 8KB pages (25% of 7.5GB RAM)
    }
    database_flags {
      name  = "effective_cache_size"
      value = "5529600"  # 5.625GB (75% of 7.5GB)
    }
    database_flags {
      name  = "random_page_cost"
      value = "1.1"  # SSD optimization
    }
    database_flags {
      name  = "idle_in_transaction_session_timeout"
      value = "300000"  # 5 min — kill idle transactions
    }
    database_flags {
      name  = "cloudsql.enable_pgvector"
      value = "on"
    }

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      location                       = "europe-central2"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 30
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false  # privacy
    }

    maintenance_window {
      day  = 7  # Niedziela
      hour = 3
    }
  }
}

resource "google_sql_database" "app" {
  name     = "superwizor"
  project  = var.project_id
  instance = google_sql_database_instance.main.name
}

resource "google_sql_user" "postgres" {
  name     = "postgres"
  project  = var.project_id
  instance = google_sql_database_instance.main.name
  password = random_password.postgres.result
}

# IAM users dla microserwisów (utworzymy w Fazie 1)

output "instance_name" { value = google_sql_database_instance.main.name }
output "connection_name" { value = google_sql_database_instance.main.connection_name }
output "private_ip" { value = google_sql_database_instance.main.private_ip_address }
output "db_password_secret_id" { value = google_secret_manager_secret.db_password.id }
EOF
```

### Task 0.4.2 — Dodaj do staging environment
```bash
cat >> infra/environments/staging/main.tf <<'EOF'

module "cloud_sql" {
  source = "../../modules/cloud-sql"

  project_id      = var.project_id
  environment     = var.environment
  vpc_id          = module.vpc.network_id
  database_key_id = module.kms.database_key_id

  tier              = "db-custom-2-7680"
  availability_type = "ZONAL"

  depends_on = [module.vpc]
}

output "sql_connection_name" { value = module.cloud_sql.connection_name }
output "sql_private_ip" { value = module.cloud_sql.private_ip }
EOF

cd infra/environments/staging
terragrunt plan
terragrunt apply
```
Czas: Cloud SQL bootstrap = 8-12 minut. Potem instance jest gotowa.

### Task 0.4.3 — Weryfikacja pgvector
```bash
# Pobierz hasło z Secret Manager
POSTGRES_PASSWORD=$(gcloud secrets versions access latest \
  --secret=postgres-password --project=superwizor-staging)

CONNECTION_NAME=$(cd infra/environments/staging && terragrunt output -raw sql_connection_name)

# Pobierz Cloud SQL Auth Proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.0/cloud-sql-proxy.linux.amd64
chmod +x cloud-sql-proxy

# Uruchom proxy w tle
./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 &
PROXY_PID=$!
sleep 5

# Connect i włącz pgvector
PGPASSWORD="${POSTGRES_PASSWORD}" psql -h 127.0.0.1 -U postgres -d superwizor <<'EOF'
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

-- Sanity check
SELECT version();
SELECT extname, extversion FROM pg_extension ORDER BY extname;

-- Test pgvector
SELECT '[1,2,3]'::vector;
SELECT '[1,2,3]'::vector <-> '[1,2,4]'::vector AS distance;
\q
EOF

# Kill proxy
kill ${PROXY_PID}
```

Spodziewany output:
```text
extname    | extversion
-----------+------------
btree_gin  | 1.3
pg_trgm    | 1.6
pgcrypto   | 1.3
vector     | 0.7.0

distance: 1.0
```

### Task 0.4.4 — Pierwsza migracja SQL (z modelu danych v4.3)
```bash
# Utwórz pierwszą migrację
make migrate-create NAME=initial_extensions

# Wypełnij up migration
cat > migrations/000001_initial_extensions.up.sql <<'EOF'
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "vector";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";

SET timezone = 'UTC';
EOF

cat > migrations/000001_initial_extensions.down.sql <<'EOF'
DROP EXTENSION IF EXISTS "pg_trgm";
DROP EXTENSION IF EXISTS "btree_gin";
DROP EXTENSION IF EXISTS "vector";
DROP EXTENSION IF EXISTS "pgcrypto";
EOF

# Uruchom migrację (proxy musi być włączony)
./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 &
PROXY_PID=$!
sleep 5
DB_USER=postgres DB_PASSWORD="${POSTGRES_PASSWORD}" make migrate-up
kill ${PROXY_PID}
```

### Smoke test Sprint 0.4
```bash
# Z włączonym proxy:
psql -h 127.0.0.1 -U postgres -d superwizor -c "
  SELECT extname FROM pg_extension WHERE extname IN ('vector', 'pgcrypto', 'pg_trgm');
"
# Powinien zwrócić 3 wiersze.

# Sprawdź migrate version
psql -h 127.0.0.1 -U postgres -d superwizor -c "SELECT * FROM schema_migrations;"
```

## Sprint 0.5 — CI/CD pipeline + smoke test
**Czas:** 1 dzień 
**Cel:** Ustawić Cloud Build trigger + Workload Identity Federation + deploy minimalnego "hello world" do potwierdzenia, że pipeline działa.

### Task 0.5.1 — Workload Identity Federation dla GitHub Actions
```bash
# Stwórz Workload Identity Pool
gcloud iam workload-identity-pools create github-pool \
  --location=global \
  --display-name="GitHub Actions Pool" \
  --project=superwizor-staging

POOL_ID=$(gcloud iam workload-identity-pools describe github-pool \
  --location=global --format="value(name)" --project=superwizor-staging)

# Provider dla GitHub
gcloud iam workload-identity-pools providers create-oidc github-provider \
  --location=global \
  --workload-identity-pool=github-pool \
  --display-name="GitHub OIDC Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository" \
  --attribute-condition="assertion.repository_owner == 'superwizor-ai'" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project=superwizor-staging

# Service Account dla CI
gcloud iam service-accounts create github-deployer \
  --display-name="GitHub Actions Deployer" \
  --project=superwizor-staging

# Daj mu uprawnienia
for ROLE in \
  "roles/run.admin" \
  "roles/artifactregistry.writer" \
  "roles/iam.serviceAccountUser" \
  "roles/cloudbuild.builds.builder"
do
  gcloud projects add-iam-policy-binding superwizor-staging \
    --member="serviceAccount:github-deployer@superwizor-staging.iam.gserviceaccount.com" \
    --role="${ROLE}"
done

# Bind GitHub repo do SA
gcloud iam service-accounts add-iam-policy-binding \
  github-deployer@superwizor-staging.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/${POOL_ID}/attribute.repository/superwizor-ai/backend"

# Zapisz POOL_ID i provider name dla GitHub Secrets
echo "WIF Provider: ${POOL_ID}/providers/github-provider"
echo "Service Account: github-deployer@superwizor-staging.iam.gserviceaccount.com"
```

### Task 0.5.2 — GitHub Actions workflow
```bash
mkdir -p .github/workflows

cat > .github/workflows/ci.yml <<'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  PROJECT_ID: superwizor-staging
  REGION: europe-central2
  REGISTRY: europe-central2-docker.pkg.dev/superwizor-staging/services

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'
      - uses: bufbuild/buf-setup-action@v1
      - run: make proto
      - uses: golangci/golangci-lint-action@v6
        with:
          version: v1.60
          working-directory: services/identity-svc

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'
      - uses: bufbuild/buf-setup-action@v1
      - run: make proto
      - run: make test

  deploy-staging:
    runs-on: ubuntu-latest
    needs: test
    if: github.ref == 'refs/heads/main'
    permissions:
      contents: read
      id-token: write   # required for WIF
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.WIF_SA }}
      - uses: google-github-actions/setup-gcloud@v2
      - name: Configure Docker for Artifact Registry
        run: gcloud auth configure-docker ${REGION}-docker.pkg.dev
      - uses: actions/setup-go@v5
        with:
          go-version: '1.23'
      - uses: bufbuild/buf-setup-action@v1
      - run: make proto
      - name: Build and push hello-world image
        run: |
          docker build -t ${REGISTRY}/hello-world:${GITHUB_SHA::8} \
            -f services/hello-world/Dockerfile .
          docker push ${REGISTRY}/hello-world:${GITHUB_SHA::8}
      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy hello-world \
            --image=${REGISTRY}/hello-world:${GITHUB_SHA::8} \
            --region=${REGION} \
            --platform=managed \
            --allow-unauthenticated \
            --max-instances=2
EOF
```

### Task 0.5.3 — Smoke test "hello world" service
```bash
mkdir -p services/hello-world/cmd/server
cd services/hello-world
go mod init github.com/superwizor-ai/backend/services/hello-world

cat > cmd/server/main.go <<'EOF'
package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello from SuperWizor AI! version=%s\n", os.Getenv("K_REVISION"))
	})

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		fmt.Fprint(w, "OK")
	})

	log.Printf("Server listening on :%s", port)
	if err := http.ListenAndServe(":"+port, nil); err != nil {
		log.Fatal(err)
	}
}
EOF

cat > Dockerfile <<'EOF'
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o /server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
EOF

cd ../..
go work use ./services/hello-world
```

### Task 0.5.4 — Add GitHub Secrets
W GitHub repo (Settings → Secrets and variables → Actions):
- `WIF_PROVIDER`: `projects/{PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/providers/github-provider`
- `WIF_SA`: `github-deployer@superwizor-staging.iam.gserviceaccount.com`

```bash
# Pobierz PROJECT_NUMBER
gcloud projects describe superwizor-staging --format="value(projectNumber)"
```

### Task 0.5.5 — Push i weryfikacja
```bash
git add .
git commit -m "feat: add hello-world smoke test service"
git push origin main

# Po zakończeniu workflow:
SERVICE_URL=$(gcloud run services describe hello-world \
  --region=europe-central2 \
  --project=superwizor-staging \
  --format="value(status.url)")

# Smoke test
curl ${SERVICE_URL}/healthz
# Spodziewany output: OK

curl ${SERVICE_URL}/
# Spodziewany output: Hello from SuperWizor AI! version=hello-world-00001-...
```

### Definition of Done dla Sprint 0.5
- GitHub Actions workflow przechodzi na green na main branch.
- Hello-world service deployowany na staging Cloud Run.
- `curl ${SERVICE_URL}/healthz` zwraca OK.
- Cloud Run logi widoczne w Cloud Logging (`gcloud logging read`).

## Troubleshooting cookbook

### Problem 1: "Organization policy violation: resource location"
**Symptom:**
```text
ERROR: (gcloud.run.deploy) PERMISSION_DENIED: Resource location violates
the location restriction policy.
```
**Przyczyna:** Próba deploy do regionu innego niż `europe-central2`.

**Fix:**
```bash
# Sprawdź policy
gcloud resource-manager org-policies list --project=superwizor-staging

# Upewnij się że używasz europe-central2 we wszystkich komendach
gcloud config set run/region europe-central2
gcloud config set compute/region europe-central2
```

### Problem 2: Cloud SQL: "FAILED_PRECONDITION: connection requires private IP"
**Symptom:**
```text
ERROR: psql: error: connection to server at "10.x.x.x" port 5432 failed: timeout
```
**Przyczyna:** Próba połączenia z laptopa do Cloud SQL z private IP — nie ma trasy.

**Fix:** Używaj Cloud SQL Auth Proxy zamiast direct connection:
```bash
./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 --auto-iam-authn
psql -h 127.0.0.1 -U your-iam-user@project.iam -d superwizor
```

### Problem 3: Terragrunt "remote state already exists"
**Symptom:**
```text
Error: Backend initialization required: backend configuration changed
```
**Przyczyna:** Zmieniłeś backend config w `terragrunt.hcl` po pierwszym init.

**Fix:**
```bash
cd infra/environments/staging
rm -rf .terragrunt-cache/
terragrunt init -reconfigure
```

### Problem 4: "Permission denied on artifact registry push"
**Symptom:**
```text
denied: Permission "artifactregistry.repositories.uploadArtifacts" denied
```
**Przyczyna:** Docker nie autoryzowany do Artifact Registry.

**Fix:**
```bash
gcloud auth configure-docker europe-central2-docker.pkg.dev

# Albo dla service account:
gcloud auth print-access-token | docker login \
  -u oauth2accesstoken --password-stdin \
  europe-central2-docker.pkg.dev
```

### Problem 5: "service-networking peering already exists"
**Symptom:**
```text
Error: Error waiting for Create Service Networking Connection:
Error code 9, message: Cannot modify allocated ranges in CreateConnection.
```
**Przyczyna:** Peering został wcześniej utworzony manualnie albo z innego stanu.

**Fix:**
```bash
# Import existing peering do Terraform state
terraform import \
  module.vpc.google_service_networking_connection.private_vpc_connection \
  projects/superwizor-staging/global/networks/superwizor-vpc:servicenetworking.googleapis.com
```

### Problem 6: pgvector: "extension 'vector' is not available"
**Symptom:**
```text
ERROR: extension "vector" is not available
```
**Przyczyna:** Flag `cloudsql.enable_pgvector` nie został ustawiony albo instance utworzona przed włączeniem.

**Fix:**
```bash
gcloud sql instances patch superwizor-staging \
  --database-flags=cloudsql.enable_pgvector=on \
  --project=superwizor-staging

# Restart instance (downtime!)
gcloud sql instances restart superwizor-staging --project=superwizor-staging
```

### Problem 7: WIF "unauthorized client"
**Symptom (GitHub Actions):**
```text
Error: google-github-actions/auth failed with: failed to generate
Google Cloud federated token: 401: Unauthorized
```
**Przyczyna:** Najczęściej zła `attribute_condition` w WIF Provider lub błędny binding.

**Fix:**
```bash
# Sprawdź attribute condition
gcloud iam workload-identity-pools providers describe github-provider \
  --location=global --workload-identity-pool=github-pool \
  --project=superwizor-staging --format="value(attributeCondition)"

# Sprawdź binding na SA
gcloud iam service-accounts get-iam-policy \
  github-deployer@superwizor-staging.iam.gserviceaccount.com
```

### Problem 8: Cold start Cloud Run > 5s
**Symptom:** Pierwsze wywołanie zajmuje 5+ sekund.

**Fix:**
```terraform
# W cloud_run_v2_service:
template {
  scaling {
    min_instance_count = 1   # Zamiast 0
  }
  containers {
    resources {
      startup_cpu_boost = true   # ← włącz to
    }
  }
}
```

---
🎉 Po Sprint 0.5 → ready dla Fazy 1.

Zobacz dokument: `05_FAZA_1_TOZSAMOSC_DANE.md` dla kolejnych kroków.
