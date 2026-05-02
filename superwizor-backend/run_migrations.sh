#!/bin/bash
set -e

# Get password from Secret Manager
POSTGRES_PASSWORD=$(gcloud secrets versions access latest --secret=superwizor-db-password --project=superwizor-ai-25ecd)
CONNECTION_NAME="superwizor-ai-25ecd:europe-central2:superwizor-db-4d61ad78"

# Run proxy in background
./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 &
PROXY_PID=$!

echo "Waiting for proxy to start..."
sleep 5

# URL encode password for golang-migrate
ENCODED_PASSWORD=$(jq -nr --arg v "$POSTGRES_PASSWORD" '$v|@uri')

# Run migration
echo "Running migration..."
DB_USER="superwizor_app" DB_PASSWORD="${ENCODED_PASSWORD}" make migrate-up || { echo "Migration failed"; kill ${PROXY_PID}; exit 1; }

echo "Migration successful. Killing proxy..."
kill ${PROXY_PID}

