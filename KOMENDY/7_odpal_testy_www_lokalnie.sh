#!/usr/bin/env bash
# 7_odpal_testy_www_lokalnie.sh
set -euo pipefail

echo "🌐 Uruchamianie lokalnych testów i walidacji dla marketing-site..."

# Wejdź do katalogu marketing-site
cd "$(dirname "$0")/../marketing-site"

echo "--------------------------------------------------------"
echo "1. Sprawdzanie spójności tłumaczeń PL ↔ EN (l10n parity)..."
pnpm run check:l10n
echo "✅ Tłumaczenia są spójne!"

echo "--------------------------------------------------------"
echo "2. Uruchamianie testu smoke dla klientów Connect-RPC..."
pnpm exec tsx scripts/smoke-connect.mjs
echo "✅ Testy Connect-RPC zaliczone!"

echo "--------------------------------------------------------"
echo "3. Kompilowanie strony (pnpm build / TypeScript check)..."
pnpm build
echo "✅ Kompilacja Next.js / TypeScript zakończona sukcesem!"

echo "--------------------------------------------------------"
echo "🎉 Wszystkie testy i walidacje dla strony marketingowej zakończone sukcesem!"
