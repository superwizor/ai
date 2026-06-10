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

# Automatyczna konfiguracja poświadczeń z sa-key.json (jeśli istnieje)
SA_KEY_PATH="${BACKEND_DIR}/../sa-key.json"
if [[ -s "${SA_KEY_PATH}" ]]; then
  echo "🔑 Wykryto plik sa-key.json. Konfiguruję uwierzytelnianie kontem usługowym GCP..."
  export GOOGLE_APPLICATION_CREDENTIALS="${SA_KEY_PATH}"
  # Aktywujemy konto usługowe w gcloud na potrzeby pobierania sekretów i zarządzania nimi
  gcloud auth activate-service-account --key-file="${SA_KEY_PATH}" --quiet >/dev/null 2>&1 || true
fi

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
    # Zachowaj hasło w formacie zakodowanym (URL-encoded) — znaki specjalne (np. !, %, &)
    # rozbiłyby parser URL bibliotek Go/migrate, gdyby były odkodowane w DSN.
    DB_PASSWORD="${ENCODED_PASS}"
    echo "✅ Pomyślnie pobrano hasło z GCP Secret Manager!"
  else
    echo "⚠️  Nie udało się pobrać hasła z GCP (brak zalogowania w gcloud?). Używam domyślnego hasła deweloperskiego."
  fi
fi

LOCAL_DSN="postgres://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}?sslmode=disable"

# Porty lokalne dla poszczególnych serwisów
PORT_IDENTITY="8080"
PORT_BILLING="8081"
PORT_CLINICAL="8082"
PORT_INGESTION="8083"
PORT_NOTIFICATION="8084"

LOGS_DIR="${BACKEND_DIR}/logs"
mkdir -p "${LOGS_DIR}"

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

echo "============================================================"
echo "🚀 Uruchamianie lokalnego środowiska deweloperskiego SuperWizor"
echo "============================================================"
echo "📁 Katalog logów: ${LOGS_DIR}"
echo "🗄️ DSN bazy: ${LOCAL_DSN}"

# 1. Sprawdzenie połączenia z bazą danych i ewentualne uruchomienie proxy
echo -n "🔍 Sprawdzanie połączenia z bazą danych... "
if ! nc -z -w 1 "${DB_HOST}" "${DB_PORT}" >/dev/null 2>&1; then
  if [[ "${DB_HOST}" == "127.0.0.1" && "${DB_PORT}" == "5432" ]]; then
    PROXY_BIN="${BACKEND_DIR}/../cloud-sql-proxy"
    if [[ -f "${PROXY_BIN}" ]]; then
      echo -e "\n🔄 Port ${DB_PORT} jest nieaktywny. Wykryto cloud-sql-proxy w katalogu głównym."
      echo "🚀 Automatycznie uruchamiam cloud-sql-proxy w tle..."
      "${PROXY_BIN}" superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de --port=5432 > "${BACKEND_DIR}/../proxy.log" 2>&1 &
      PROXY_PID=$!
      PIDS+=("${PROXY_PID}")
      echo "⏳ Oczekiwanie na inicjalizację połączenia przez proxy (3s)..."
      sleep 3
      if ! nc -z -w 1 "${DB_HOST}" "${DB_PORT}" >/dev/null 2>&1; then
        echo "❌ Błąd: Uruchomiono cloud-sql-proxy (PID ${PROXY_PID}), ale port ${DB_PORT} nadal nie odpowiada."
        echo "Sprawdź szczegóły w pliku logu: proxy.log"
        PROXY_LOG="${BACKEND_DIR}/../proxy.log"
        if [[ -f "${PROXY_LOG}" ]] && grep -q -E "invalid_rapt|invalid_grant|cannot fetch token" "${PROXY_LOG}"; then
          echo -e "\n🔑 [GCP Auth Alert] Wykryto problem z autoryzacją GCP w proxy.log!"
          echo "Aby się zautentykować, uruchom w terminalu:"
          echo "   gcloud auth login && gcloud auth application-default login"
        fi
        exit 1
      fi
      echo "✅ Połączenie nawiązane pomyślnie!"
    else
      echo -e "\n❌ Błąd: Lokalna baza danych na porcie ${DB_PORT} nie działa i brak pliku cloud-sql-proxy."
      echo "Upewnij się, że lokalna baza (np. w Dockerze) lub proxy działają."
      exit 1
    fi
  else
    echo -e "\n❌ Błąd: Lokalna baza danych na porcie ${DB_PORT} nie jest aktywna!"
    exit 1
  fi
else
  echo "OK!"
fi

# 2. Uruchomienie migracji
echo "🔄 Uruchamianie migracji bazy danych..."
(cd "${BACKEND_DIR}" && DB_USER="${DB_USER}" DB_PASSWORD="${DB_PASSWORD}" make migrate-up) || {
  echo "❌ Migracje nie powiodły się! Sprawdź logi lub dane uwierzytelniające."
  PROXY_LOG="${BACKEND_DIR}/../proxy.log"
  if [[ -f "${PROXY_LOG}" ]] && grep -q -E "invalid_rapt|invalid_grant|cannot fetch token" "${PROXY_LOG}"; then
    echo -e "\n🔑 [GCP Auth Alert] Wykryto problem z autoryzacją GCP w proxy.log!"
    echo "Aby się zautentykować, uruchom w terminalu:"
    echo "   gcloud auth login && gcloud auth application-default login"
  fi
  exit 1
}

# 3. Kompilacja serwisów (szybki check czy kod się buduje przed uruchomieniem)
echo "🛠️ Kompilacja mikrousług..."
(cd "${BACKEND_DIR}" && make build) || {
  echo "❌ Kompilacja nie powiodła się!"
  exit 1
}

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
SIGN_URL_SA_EMAIL="ingestion-svc@superwizor-ai-25ecd.iam.gserviceaccount.com" \
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
