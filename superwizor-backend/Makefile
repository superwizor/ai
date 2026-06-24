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
	@for dir in $$(find . -name "go.mod" -not -path "*/node_modules/*" -not -path "*/.tmp/*" -exec dirname {} \;); do \
		echo "Linting $$dir"; \
		(cd $$dir && golangci-lint run ./...) || exit 1; \
	done

test:  ## Run unit tests for all modules
	@for dir in $$(find . -name "go.mod" -not -path "*/node_modules/*" -not -path "*/.tmp/*" -exec dirname {} \;); do \
		echo "Testing $$dir"; \
		(cd $$dir && go test -short -race -coverprofile=cov.out ./...) || exit 1; \
	done

build:  ## Build all service binaries
	@for svc in identity-svc billing-svc clinical-svc ingestion-svc notification-svc; do \
		echo "Building $$svc"; \
		go build -o bin/$$svc ./services/$$svc/cmd/server; \
	done
	@echo "Building purger"
	@go build -o bin/purger ./services/clinical-svc/cmd/purger

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

run-local: ## Start all backend services locally in the background
	./scripts/run_local_backend.sh

test-e2e-local: ## Run E2E tests against local backend services
	@echo "Running E2E tests against localhost..."
	cd tests && \
	IDENTITY_SVC_URL="http://127.0.0.1:8080" \
	CLINICAL_SVC_URL="http://127.0.0.1:8082" \
	INGESTION_SVC_URL="http://127.0.0.1:8083" \
	go test -tags=e2e -timeout=30m -v ./e2e/... | python3 ../scripts/test_progress.py

clean:  ## Clean build artifacts
	rm -rf bin/ gen/ cov.out

