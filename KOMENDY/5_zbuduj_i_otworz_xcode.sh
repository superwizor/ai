#!/usr/bin/env bash
# 5_zbuduj_i_otworz_xcode.sh
set -e
echo "🛠️ Budowanie wersji produkcyjnej iOS i otwieranie projektu Xcode..."
cd "$(dirname "$0")/../flutter-app/superwizor"

echo "🧹 1. Czyszczenie starych buildów..."
flutter clean
flutter pub get

echo "📦 2. Budowanie paczki IPA dla iOS..."
flutter build ipa

echo "🖥️ 3. Otwieranie Xcode Workspace..."
open ios/Runner.xcworkspace

echo "============================================================"
echo "🎉 Xcode został otwarty!"
echo "👉 Aby wysłać wersję do App Store:"
echo "   1. W Xcode wybierz z górnego menu Product -> Archive."
echo "   2. Po ukończeniu, w oknie Organizer kliknij niebieski przycisk 'Distribute App'."
echo "============================================================"
