#!/usr/bin/env bash
# 6_uruchom_www_lokalnie.sh
set -e
echo "🌐 Uruchamianie strony marketingowej WWW lokalnie..."
cd "$(dirname "$0")/../marketing-site"

# Próba otwarcia przeglądarki w tle
echo "Otwieranie http://localhost:3000 w przeglądarce..."
open "http://localhost:3000" || true

# Uruchomienie deweloperskiego serwera Next.js za pomocą pnpm
pnpm dev
