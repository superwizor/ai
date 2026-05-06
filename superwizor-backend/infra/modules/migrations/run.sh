#!/usr/bin/env bash
# Apply all pending golang-migrate migrations in MIGRATIONS_DIR against the
# Cloud SQL instance reachable via cloud-sql-proxy. Idempotent: golang-migrate
# tracks state in the schema_migrations table, so re-running is safe.
#
# The DB URL is fetched from a Secret Manager secret in the form:
#   postgres://user:password@host:port/dbname?sslmode=...
# We extract the password and rebuild the URL pointing at the local proxy.

set -euo pipefail

: "${PROJECT_ID:?}"
: "${DB_CONNECTION_NAME:?}"
: "${DB_URL_SECRET_ID:?}"
: "${DB_USER:?}"
: "${DB_NAME:?}"
: "${MIGRATIONS_DIR:?}"
: "${CLOUD_SQL_PROXY:?}"
: "${PROXY_PORT:?}"

# Terragrunt invokes terraform from a cache directory, so any path passed in
# from terraform that uses path.cwd lands in the cache rather than the repo.
# Recover the real repo root from PWD (which still contains '/superwizor-backend/'
# because the cache lives under it) and rewrite cache-relative paths.
if [[ "$CLOUD_SQL_PROXY" == *"/.terragrunt-cache/"* || ! -e "$CLOUD_SQL_PROXY" ]]; then
  REPO_ROOT="${PWD%%/superwizor-backend/*}/superwizor-backend"
  if [[ -d "$REPO_ROOT" ]]; then
    [[ -e "$CLOUD_SQL_PROXY" ]] || CLOUD_SQL_PROXY="$REPO_ROOT/cloud-sql-proxy"
    [[ -e "$MIGRATIONS_DIR" ]] || MIGRATIONS_DIR="$REPO_ROOT/migrations"
  fi
fi

if [[ ! -x "$CLOUD_SQL_PROXY" ]]; then
  echo "cloud-sql-proxy not found or not executable: $CLOUD_SQL_PROXY" >&2
  exit 1
fi

# Catch arch mismatches before they show up as a useless 'Bad CPU type' from the OS
if ! "$CLOUD_SQL_PROXY" --version >/dev/null 2>&1; then
  echo "cloud-sql-proxy at $CLOUD_SQL_PROXY can't run on this host (likely arch mismatch)." >&2
  echo "Host: $(uname -s)/$(uname -m). Binary: $(file -b "$CLOUD_SQL_PROXY" 2>/dev/null || echo unknown)" >&2
  echo "Download the matching build from https://github.com/GoogleCloudPlatform/cloud-sql-proxy/releases" >&2
  exit 1
fi

if ! command -v migrate >/dev/null 2>&1; then
  echo "golang-migrate CLI ('migrate') not found in PATH" >&2
  exit 1
fi

# gcloud may live outside the default PATH (e.g. ~/google-cloud-sdk/bin)
if ! command -v gcloud >/dev/null 2>&1; then
  for candidate in "$HOME/google-cloud-sdk/bin/gcloud" /usr/local/google-cloud-sdk/bin/gcloud; do
    if [[ -x "$candidate" ]]; then
      export PATH="$(dirname "$candidate"):$PATH"
      break
    fi
  done
fi
command -v gcloud >/dev/null 2>&1 || { echo "gcloud not found" >&2; exit 1; }

echo "[migrations] Fetching DB URL from Secret Manager (${DB_URL_SECRET_ID})..."
DB_URL_RAW=$(gcloud secrets versions access latest \
  --secret="${DB_URL_SECRET_ID}" \
  --project="${PROJECT_ID}")

if [[ -z "$DB_URL_RAW" ]]; then
  echo "[migrations] Empty value for secret ${DB_URL_SECRET_ID}" >&2
  exit 1
fi

echo "[migrations] Starting cloud-sql-proxy on port ${PROXY_PORT} for ${DB_CONNECTION_NAME}..."
"$CLOUD_SQL_PROXY" "${DB_CONNECTION_NAME}" --port="${PROXY_PORT}" >/tmp/cloud-sql-proxy.log 2>&1 &
PROXY_PID=$!

cleanup() {
  if kill -0 "$PROXY_PID" 2>/dev/null; then
    kill "$PROXY_PID" 2>/dev/null || true
    wait "$PROXY_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

# Wait for proxy to accept connections (up to ~30s)
for i in $(seq 1 30); do
  if (echo > "/dev/tcp/127.0.0.1/${PROXY_PORT}") >/dev/null 2>&1; then
    echo "[migrations] Proxy ready after ${i}s."
    break
  fi
  if ! kill -0 "$PROXY_PID" 2>/dev/null; then
    echo "[migrations] cloud-sql-proxy died; tail of log:" >&2
    tail -n 50 /tmp/cloud-sql-proxy.log >&2 || true
    exit 1
  fi
  sleep 1
done

# Rewrite only the host:port in the DSN — keep the original (already URL-encoded)
# user:password as-is to avoid any double-encoding issues. Force sslmode=disable
# because cloud-sql-proxy terminates TLS for us.
LOCAL_DB_URL=$(python3 - "$DB_URL_RAW" "127.0.0.1" "$PROXY_PORT" <<'PY'
import sys, urllib.parse
raw, host, port = sys.argv[1], sys.argv[2], sys.argv[3]
u = urllib.parse.urlparse(raw)
userinfo = ""
if u.username is not None:
    userinfo = u.username
    if u.password is not None:
        userinfo += ":" + u.password
    userinfo += "@"
netloc = f"{userinfo}{host}:{port}"
q = dict(urllib.parse.parse_qsl(u.query, keep_blank_values=True))
q["sslmode"] = "disable"
new = u._replace(netloc=netloc, query=urllib.parse.urlencode(q))
print(urllib.parse.urlunparse(new))
PY
)

# Sanity-check the user matches what we expect, so a stale secret fails loud.
SECRET_USER=$(python3 -c 'import sys, urllib.parse; print(urllib.parse.urlparse(sys.argv[1]).username or "")' "$DB_URL_RAW")
if [[ -n "$SECRET_USER" && "$SECRET_USER" != "$DB_USER" ]]; then
  echo "[migrations] Secret ${DB_URL_SECRET_ID} has user='${SECRET_USER}' but module expects '${DB_USER}'." >&2
  echo "[migrations] Refusing to apply migrations with a mismatched user." >&2
  exit 1
fi

echo "[migrations] Running 'migrate up' against ${DB_NAME}..."
migrate -path "${MIGRATIONS_DIR}" -database "${LOCAL_DB_URL}" up

echo "[migrations] Done."
