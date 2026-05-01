#!/bin/sh
set -e

if [ -n "$DATABASE_URL" ]; then
  echo "Using DATABASE_URL from environment..."
  migrate -path /migrations -database "${DATABASE_URL}" up
  exit 0
fi

if [ -z "$DB_PASSWORD" ]; then
  echo "Error: DB_PASSWORD environment variable is not set."
  exit 1
fi

if [ -z "$DB_USER" ] || [ -z "$DB_HOST" ] || [ -z "$DB_NAME" ]; then
  echo "Error: DB_USER, DB_HOST, and DB_NAME must be set."
  exit 1
fi

# URL encode the password using python3
ENCODED_PASSWORD=$(python3 -c "import urllib.parse, os; print(urllib.parse.quote_plus(os.environ.get('DB_PASSWORD', '')))")

# Run golang-migrate
echo "Running migrations..."
migrate -path /migrations -database "postgres://${DB_USER}:${ENCODED_PASSWORD}@${DB_HOST}:5432/${DB_NAME}?sslmode=disable" up
