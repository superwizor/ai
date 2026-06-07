#!/usr/bin/env bash
# 2_odpal_testy_e2e_lokalnie.sh
set -euo pipefail

echo "🧪 Uruchamianie lokalnych testów E2E..."

# Konfiguracja bazy danych (zgodnie z AGENTS.md / Makefile)
DB_USER="${DB_USER:-superwizor_app}"
DB_PASSWORD="${DB_PASSWORD:-superwizor_password}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-superwizor}"

# Automatyczne pobieranie prawdziwego hasła ze stagingu z Secret Managera, jeśli deweloper używa portu 5432
if [[ "${DB_PASSWORD}" == "superwizor_password" && "${DB_HOST}" == "127.0.0.1" && "${DB_PORT}" == "5432" ]]; then
  echo "🔑 Hasło deweloperskie nie zostało podane. Próba pobrania sekretu ze stagingu GCP..."
  if DB_URL=$(gcloud secrets versions access latest --secret=postgres-database-url --project=superwizor-ai-25ecd 2>/dev/null); then
    # Wyciągnij hasło (zakodowane) z URL
    ENCODED_PASS=$(echo "${DB_URL}" | sed -E 's/postgres:\/\/[^:]+:([^@]+)@.*/\1/')
    DB_PASSWORD="${ENCODED_PASS}"
    echo "✅ Pomyślnie pobrano hasło z GCP Secret Manager!"
  else
    echo "⚠️  Nie udało się pobrać hasła z GCP. Używam domyślnego hasła deweloperskiego."
  fi
fi

export DATABASE_URL="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"

cd "$(dirname "$0")/../superwizor-backend"
make test-e2e-local
