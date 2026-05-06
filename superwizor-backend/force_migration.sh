#!/bin/bash
set -e

DB_URL=$(gcloud secrets versions access latest --secret=postgres-database-url --project=superwizor-ai-25ecd)
CONNECTION_NAME="superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de"
PASSWORD_ENCODED=$(echo $DB_URL | sed -E 's/postgres:\/\/[^:]+:([^@]+)@.*/\1/')

./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 &
PROXY_PID=$!
sleep 5

echo "Rolling back migration 8..."
migrate -path migrations -database "postgres://superwizor_app:${PASSWORD_ENCODED}@127.0.0.1:5432/superwizor?sslmode=disable" down 1

echo "Applying migration 8 again..."
migrate -path migrations -database "postgres://superwizor_app:${PASSWORD_ENCODED}@127.0.0.1:5432/superwizor?sslmode=disable" up

echo "Migration re-applied. Killing proxy..."
kill ${PROXY_PID}
