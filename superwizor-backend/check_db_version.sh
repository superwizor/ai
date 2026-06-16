#!/bin/bash
set -e

# Get database URL from Secret Manager
DB_URL=$(gcloud secrets versions access latest --secret=postgres-database-url --project=superwizor-ai-25ecd 2>/dev/null) || {
  echo "❌ BŁĄD: Nie udało się pobrać hasła z GCP Secret Manager (brak autoryzacji?)."
  echo "Uruchom te komendy w terminalu, aby się zalogować:"
  echo "   gcloud auth login"
  echo "   gcloud auth application-default login"
  exit 1
}
CONNECTION_NAME="superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de"

# Run proxy in background
./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 &
PROXY_PID=$!

echo "Waiting for proxy to start..."
sleep 5

# Extract password
PASSWORD_ENCODED=$(echo $DB_URL | sed -E 's/postgres:\/\/[^:]+:([^@]+)@.*/\1/')

# Run migration version
echo "Checking migration version..."
migrate -path migrations -database "postgres://superwizor_app:${PASSWORD_ENCODED}@127.0.0.1:5432/superwizor?sslmode=disable" version

echo "Migration version check successful. Killing proxy..."
kill ${PROXY_PID}
