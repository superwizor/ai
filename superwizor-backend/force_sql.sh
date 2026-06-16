#!/bin/bash
set -e

DB_URL=$(gcloud secrets versions access latest --secret=postgres-database-url --project=superwizor-ai-25ecd 2>/dev/null) || {
  echo "❌ BŁĄD: Nie udało się pobrać hasła z GCP Secret Manager (brak autoryzacji?)."
  echo "Uruchom te komendy w terminalu, aby się zalogować:"
  echo "   gcloud auth login"
  echo "   gcloud auth application-default login"
  exit 1
}
CONNECTION_NAME="superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de"
PASSWORD_ENCODED=$(echo $DB_URL | sed -E 's/postgres:\/\/[^:]+:([^@]+)@.*/\1/')
PASSWORD=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('${PASSWORD_ENCODED}'))")

./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 &
PROXY_PID=$!
sleep 5

echo "Applying SQL directly..."
PGPASSWORD="${PASSWORD}" psql -h 127.0.0.1 -p 5432 -U superwizor_app -d superwizor -f migrations/000008_modality_prompts_pl.up.sql

echo "SQL applied. Killing proxy..."
kill ${PROXY_PID}
