# SuperWizor AI Backend
Production-grade backend for SuperWizor AI — clinical supervision platform for psychotherapists.

## Quick start (30 minutes)

### Prerequisites
- Go 1.23+, Terraform 1.7+, gcloud CLI v521+, buf, golang-migrate
- See [Faza 0 doc](../../docs/03_FAZA_0_FUNDAMENT.md) for detailed setup

### Local development
```bash
git clone git@github.com:superwizor-ai/backend.git
cd backend

# Generate proto stubs
make proto

# Lint and test everything
make lint
make test

# Run the API service locally
cd services/api
go run main.go
```

## Repository structure
See `docs/01_ARCHITEKTURA_TECHNICZNA.md` for full architecture details.

## Documentation
- Konstytucja projektu
- Architektura techniczna
- Model danych v4.3
- Faza 0 — Fundament
- Faza 1 — Tożsamość i dane
