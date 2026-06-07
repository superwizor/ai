#!/usr/bin/env bash
# run_local_backend.sh
# Automatycznie buduje i uruchamia wszystkie 5 usług backendowych lokalnie na Twoim Macu.
# Służy do lokalnego sprawdzania aplikacji, deweloperki i szybkiego uruchamiania testów E2E na localhost.
#
# Wymagania:
#   1. Uruchomiona lokalna baza danych PostgreSQL (np. na porcie 5432).
#   2. Zalogowany gcloud (dla ew. pobierania tokenów Firebase, jeśli testy tego wymagają).

set -euo pipefail

# Folder bazowy skryptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Konfiguracja bazy danych (zgodnie z AGENTS.md / Makefile)
DB_USER="${DB_USER:-superwizor_app}"
DB_PASSWORD="${DB_PASSWORD:-superwizor_password}"
DB_HOST="${DB_HOST:-127.0.0.1}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-superwizor}"
LOCAL_DSN="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"

# Porty lokalne dla poszczególnych serwisów
PORT_IDENTITY="8080"
PORT_BILLING="8081"
PORT_CLINICAL="8082"
PORT_INGESTION="8083"
PORT_NOTIFICATION="8084"

LOGS_DIR="${BACKEND_DIR}/logs"
mkdir -p "${LOGS_DIR}"

echo "============================================================"
echo "🚀 Uruchamianie lokalnego środowiska deweloperskiego SuperWizor"
echo "============================================================"
echo "📁 Katalog logów: ${LOGS_DIR}"
echo "🗄️ DSN bazy: ${LOCAL_DSN}"

# 1. Sprawdzenie połączenia z bazą danych
echo -n "🔍 Sprawdzanie połączenia z bazą danych... "
if ! nc -z -w 1 "${DB_HOST}" "${DB_PORT}" >/dev/null 2>&1; then
  echo -e "\n❌ Błąd: Lokalna baza danych PostgreSQL na porcie ${DB_PORT} nie jest aktywna!"
  echo "Upewnij się, że baza danych działa (np. w Dockerze) i spróbuj ponownie."
  exit 1
fi
echo "OK!"

# 2. Uruchomienie migracji
echo "🔄 Uruchamianie migracji bazy danych..."
(cd "${BACKEND_DIR}" && DB_USER="${DB_USER}" DB_PASSWORD="${DB_PASSWORD}" make migrate-up) || {
  echo "❌ Migracje nie powiodły się! Sprawdź logi lub dane uwierzytelniające."
  exit 1
}

# 3. Kompilacja serwisów (szybki check czy kod się buduje przed uruchomieniem)
echo "🛠️ Kompilacja mikrousług..."
(cd "${BACKEND_DIR}" && make build) || {
  echo "❌ Kompilacja nie powiodła się!"
  exit 1
}

# Lista PID-ów procesów tła do późniejszego zabicia
PIDS=()

# Funkcja sprzątająca wywoływana przy Ctrl+C (SIGINT) lub wyjściu ze skryptu
cleanup() {
  echo -e "\n\n🧹 Zatrzymywanie lokalnych usług..."
  for pid in "${PIDS[@]}"; do
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid"
    fi
  done
  echo "✅ Wszystkie usługi zostały zatrzymane."
}
trap cleanup EXIT SIGINT SIGTERM

# 4. Uruchamianie usług w tle
echo "⚡ Uruchamianie usług..."

# A. identity-svc
echo "🟢 Uruchamianie identity-svc na porcie ${PORT_IDENTITY}..."
DATABASE_URL="${LOCAL_DSN}" \
PORT="${PORT_IDENTITY}" \
VERSION="local-dev" \
GCP_PROJECT_ID="superwizor-ai-25ecd" \
NOTIFICATION_SVC_URL="http://127.0.0.1:${PORT_NOTIFICATION}" \
"${BACKEND_DIR}/bin/identity-svc" > "${LOGS_DIR}/identity-svc.log" 2>&1 &
PIDS+=($!)

# B. billing-svc
echo "🟢 Uruchamianie billing-svc na porcie ${PORT_BILLING}..."
DATABASE_URL="${LOCAL_DSN}" \
PORT="${PORT_BILLING}" \
VERSION="local-dev" \
GCP_PROJECT_ID="superwizor-ai-25ecd" \
IDENTITY_SVC_URL="http://127.0.0.1:${PORT_IDENTITY}" \
"${BACKEND_DIR}/bin/billing-svc" > "${LOGS_DIR}/billing-svc.log" 2>&1 &
PIDS+=($!)

# C. clinical-svc
echo "🟢 Uruchamianie clinical-svc na porcie ${PORT_CLINICAL}..."
DATABASE_URL="${LOCAL_DSN}" \
PORT="${PORT_CLINICAL}" \
VERSION="local-dev" \
IDENTITY_SVC_URL="http://127.0.0.1:${PORT_IDENTITY}" \
BILLING_SVC_URL="http://127.0.0.1:${PORT_BILLING}" \
NOTIFICATION_SVC_URL="http://127.0.0.1:${PORT_NOTIFICATION}" \
KMS_KEY_URI="projects/superwizor-ai-25ecd/locations/europe-central2/keyRings/superwizor-keyring/cryptoKeys/app-data-key" \
"${BACKEND_DIR}/bin/clinical-svc" > "${LOGS_DIR}/clinical-svc.log" 2>&1 &
PIDS+=($!)

# D. ingestion-svc
echo "🟢 Uruchamianie ingestion-svc na porcie ${PORT_INGESTION}..."
DATABASE_URL="${LOCAL_DSN}" \
PORT="${PORT_INGESTION}" \
VERSION="local-dev" \
GCP_PROJECT_ID="superwizor-ai-25ecd" \
AUDIO_BUCKET_NAME="superwizor-ai-25ecd-audio-uploads" \
BILLING_SVC_URL="http://127.0.0.1:${PORT_BILLING}" \
"${BACKEND_DIR}/bin/ingestion-svc" > "${LOGS_DIR}/ingestion-svc.log" 2>&1 &
PIDS+=($!)

# E. notification-svc
echo "🟢 Uruchamianie notification-svc na porcie ${PORT_NOTIFICATION}..."
DATABASE_URL="${LOCAL_DSN}" \
PORT="${PORT_NOTIFICATION}" \
VERSION="local-dev" \
GCP_PROJECT_ID="superwizor-ai-25ecd" \
"${BACKEND_DIR}/bin/notification-svc" > "${LOGS_DIR}/notification-svc.log" 2>&1 &
PIDS+=($!)

echo "============================================================"
echo "🎉 Wszystkie usługi działają w tle!"
echo "👉 Aby uruchomić testy E2E lokalnie, otwórz nowy terminal i wpisz:"
echo "   export IDENTITY_SVC_URL=\"http://127.0.0.1:${PORT_IDENTITY}\""
echo "   export CLINICAL_SVC_URL=\"http://127.0.0.1:${PORT_CLINICAL}\""
echo "   export INGESTION_SVC_URL=\"http://127.0.0.1:${PORT_INGESTION}\""
echo "   cd superwizor-backend/tests"
echo "   go test -tags=e2e -timeout=5m -v ./e2e/... -run TestPatientLifecycle"
echo "============================================================"
echo "Podgląd logów na żywo (Naciśnij Ctrl+C aby zatrzymać wszystkie usługi):"
echo "------------------------------------------------------------"

# Pokazuj logi na bieżąco
tail -f "${LOGS_DIR}/clinical-svc.log" "${LOGS_DIR}/identity-svc.log" "${LOGS_DIR}/billing-svc.log"
