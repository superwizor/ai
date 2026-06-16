#!/usr/bin/env bash
# 6_uruchom_www_lokalnie.sh
set -e
echo "🌐 Uruchamianie strony marketingowej WWW lokalnie..."

# 1. Sprawdzenie Firebase Auth Emulator na porcie 9099
EMULATOR_PID=""
if ! nc -z -w 1 127.0.0.1 9099 >/dev/null 2>&1; then
  echo "🔥 Firebase Auth Emulator na porcie 9099 nie jest uruchomiony."
  echo "🚀 Uruchamiam emulator Firebase Auth w tle..."
  # Uruchamiamy z głównego katalogu
  cd "$(dirname "$0")/.."
  npx firebase-tools emulators:start --only auth > firebase-emulator.log 2>&1 &
  EMULATOR_PID=$!
  echo "⏳ Oczekiwanie na start emulatora (5s)..."
  sleep 5
  cd - >/dev/null
else
  echo "✅ Firebase Auth Emulator już działa na porcie 9099."
fi

# Funkcja sprzątająca
cleanup() {
  if [[ -n "${EMULATOR_PID}" ]]; then
    echo -e "\n🧹 Zatrzymywanie lokalnego emulatora Firebase..."
    kill "${EMULATOR_PID}" || true
  fi
}
trap cleanup EXIT SIGINT SIGTERM

cd "$(dirname "$0")/../marketing-site"

# Próba otwarcia przeglądarki w tle
echo "Otwieranie http://localhost:3000 w przeglądarce..."
open "http://localhost:3000" || true

# Uruchomienie deweloperskiego serwera Next.js za pomocą pnpm (wymuszamy webpack, aby uniknąć wycieków pamięci i 100% obciążenia CPU przez Turbopack)
pnpm dev --webpack
