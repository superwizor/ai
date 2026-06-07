#!/usr/bin/env bash
# 3_uruchom_apke_mac.sh
set -e
echo "📱 Uruchamianie aplikacji Flutter na komputerze Mac..."
cd "$(dirname "$0")/../flutter-app/superwizor"
flutter run -d macos "$@"
