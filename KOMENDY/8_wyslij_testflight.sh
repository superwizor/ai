#!/usr/bin/env bash
# 8_wyslij_testflight.sh
set -e
echo "🚀 Przygotowanie wersji do TestFlight..."
cd "$(dirname "$0")/../flutter-app/superwizor"

echo "🧹 1. Czyszczenie starych buildów..."
flutter clean
flutter pub get

echo "📦 2. Budowanie paczki IPA dla iOS..."
flutter build ipa

echo "🖥️ 3. Otwieranie Archiwum w Xcode Organizer..."
open build/ios/archive/Runner.xcarchive

echo "============================================================"
echo "🎉 Xcode Organizer został otwarty!"
echo "👉 Kliknij niebieski przycisk 'Distribute App' po prawej stronie, aby wysłać aplikację do TestFlight."
echo "============================================================"
