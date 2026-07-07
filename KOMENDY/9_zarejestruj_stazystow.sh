#!/usr/bin/env bash
# 9_zarejestruj_stazystow.sh
set -e

echo "🔑 Upewnij się, że jesteś zalogowany w gcloud w swojej przeglądarce przed uruchomieniem."
echo "👉 Jeśli nie, uruchom najpierw:"
echo "   gcloud auth login"
echo "   gcloud auth application-default login"
echo "------------------------------------------------------------"

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROXY_BIN="${ROOT_DIR}/cloud-sql-proxy"

PROXY_PID=""
# Zamykamy proxy po wyjściu ze skryptu w razie gdybyśmy je uruchomili
cleanup() {
    if [ -n "$PROXY_PID" ]; then
        echo "🧹 Zatrzymywanie cloud-sql-proxy..."
        kill "$PROXY_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT SIGINT SIGTERM

if ! nc -z -w 1 127.0.0.1 5432 >/dev/null 2>&1; then
    if [ -f "$PROXY_BIN" ]; then
        echo "🚀 Port 5432 jest wolny. Uruchamiam cloud-sql-proxy w tle..."
        "$PROXY_BIN" superwizor-ai-25ecd:europe-central2:superwizor-db-bc4c27de --port=5432 > "${ROOT_DIR}/proxy_seed.log" 2>&1 &
        PROXY_PID=$!
        echo "⏳ Oczekiwanie na połączenie proxy (3 sekundy)..."
        sleep 3
    else
        echo "❌ Błąd: brak cloud-sql-proxy w folderze głównym i port 5432 jest nieaktywny."
        exit 1
    fi
else
    echo "ℹ️ Port 5432 jest aktywny (używam działającego połączenia/proxy)..."
fi

# Ustawiamy DSN wskazujący na lokalny port z URL-encoded hasłem
export DATABASE_URL="postgres://superwizor_app:Zjee%21ZoYyd78%25%26lCk-%7D47N74J-9OE%21M%21@127.0.0.1:5432/superwizor?sslmode=disable"

echo "🌸 Rozpoczynam rejestrację w Firebase Auth i bazie danych..."
cd "${ROOT_DIR}/superwizor-backend"
go run scripts/seed_interns.go
