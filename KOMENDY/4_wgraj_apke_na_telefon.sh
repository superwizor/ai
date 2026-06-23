#!/usr/bin/env bash
# 4_wgraj_apke_na_telefon.sh
# Buduje i wgrywa aplikację na podłączone urządzenie iOS (iPhone/iPad).
#
# WAŻNE: iOS 26+ blokuje JIT kompilację (mprotect), dlatego debug mode
# crashuje na fizycznym urządzeniu. Używamy --profile jako domyślny tryb:
# - AOT kompilacja (nie JIT) → działa na iOS 26+
# - Zachowuje obserwability (DevTools)  
# - Szybkie jak release
set -e

echo "📲 Wgrywanie aplikacji Flutter na podłączone urządzenie iOS..."
echo "Upewnij się, że urządzenie jest podłączone kablem, odblokowane i włączone."
echo ""

cd "$(dirname "$0")/../flutter-app/superwizor"

# Parse mode flag (default: profile for iOS 26+ compatibility)
MODE="${1:---profile}"
echo "🔧 Tryb: $MODE"
echo ""

flutter run -d "$(flutter devices 2>&1 | grep '• ios' | head -1 | sed -E 's/.*• ([^ ]+) *• ios.*/\1/')" "$MODE"
