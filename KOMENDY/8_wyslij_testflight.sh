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

# Wczytanie konfiguracji z credentials.env jeśli istnieje
ENV_FILE="$(dirname "$0")/../../credentials.env"
if [ -f "$ENV_FILE" ]; then
    APP_STORE_ISSUER_ID=$(grep APP_STORE_ISSUER_ID "$ENV_FILE" | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')
    APP_STORE_KEY_ID=$(grep APP_STORE_KEY_ID "$ENV_FILE" | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')
fi

if [ -n "$APP_STORE_ISSUER_ID" ] && [ -n "$APP_STORE_KEY_ID" ]; then
    echo "🚀 3. Wykryto dane API Apple! Rozpoczynam automatyczną wysyłkę do TestFlight za pomocą xcrun altool..."
    # Uruchamiamy wysyłkę wygenerowanego pliku .ipa z folderu build/ios/ipa/
    xcrun altool --upload-app --type ios --file build/ios/ipa/*.ipa --apiKey "$APP_STORE_KEY_ID" --apiIssuer "$APP_STORE_ISSUER_ID"
    
    echo "============================================================"
    echo "🎉 Sukces! Aplikacja została automatycznie przesłana do TestFlight."
    echo "👉 Wejdź za ok. 10-15 minut do App Store Connect, aby sprawdzić przetwarzanie paczki."
    echo "============================================================"
else
    echo "🖥️ 3. Otwieranie Archiwum w Xcode Organizer (brak klucza API do autouploadu)..."
    open build/ios/archive/Runner.xcarchive
    
    echo "============================================================"
    echo "🎉 Xcode Organizer został otwarty!"
    echo "👉 Kliknij niebieski przycisk 'Distribute App' po prawej stronie, aby wysłać aplikację do TestFlight."
    echo "============================================================"
fi
