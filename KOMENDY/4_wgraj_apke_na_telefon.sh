#!/usr/bin/env bash
# 4_wgraj_apke_na_telefon.sh
set -e
echo "📲 Wgrywanie aplikacji Flutter na podłączone urządzenie (telefon/tablet/symulator)..."
echo "Upewnij się, że urządzenie jest podłączone kablem, odblokowane i włączone."
cd "$(dirname "$0")/../flutter-app/superwizor"
flutter run
