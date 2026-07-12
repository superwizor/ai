#!/usr/bin/env bash
# 10_wyslij_googleplay.sh
set -e
echo "🚀 Przygotowanie wersji do Google Play..."

# Wyszukaj i załaduj zmienne środowiskowe z credentials.env jeśli istnieje
ENV_FILE="$(dirname "$0")/../credentials.env"
PLAY_KEY_PATH="$(dirname "$0")/../play-sa-key.json"

if [ -f "$ENV_FILE" ]; then
    # Wyciągnij ścieżkę klucza jeśli jest zdefiniowana w credentials.env
    CUSTOM_KEY_PATH=$(grep PLAY_STORE_JSON_KEY_PATH "$ENV_FILE" | cut -d'=' -f2 | tr -d '\r' | tr -d ' ')
    if [ -n "$CUSTOM_KEY_PATH" ]; then
        PLAY_KEY_PATH="$(dirname "$0")/../$CUSTOM_KEY_PATH"
    fi
fi

# 1. Informacja o kluczu API Google Play
if [ ! -f "$PLAY_KEY_PATH" ]; then
    echo "ℹ️  Brak pliku klucza w: $PLAY_KEY_PATH. Spróbujemy użyć lokalnych poświadczeń gcloud (ADC)..."
    # Upewnij się, czy użytkownik ma wygenerowane ADC
    if [ ! -f "$HOME/.config/gcloud/application_default_credentials.json" ]; then
        echo "⚠️  Brak lokalnych poświadczeń ADC. Jeśli skrypt się wyłoży, uruchom w terminalu:"
        echo "   gcloud auth application-default login"
        echo ""
    fi
else
    echo "🔑 Wykryto plik klucza: $PLAY_KEY_PATH"
fi

# 2. Budowanie paczki
cd "$(dirname "$0")/../flutter-app/superwizor"
echo "🧹 1. Czyszczenie starych buildów..."
flutter clean
flutter pub get

echo "📦 2. Budowanie paczki AAB dla Android..."
flutter build appbundle --release

# 3. Pobranie tokenu autoryzacji z gcloud i wysyłka
echo "🚀 3. Budowanie i uruchamianie skryptu wysyłki..."
TOKEN=$(gcloud auth print-access-token 2>/dev/null || echo "")
cd ../../superwizor-backend
go run scripts/upload_to_play.go -key "$PLAY_KEY_PATH" -aab "../flutter-app/superwizor/build/app/outputs/bundle/release/app-release.aab" -track "internal" -token "$TOKEN"

echo "============================================================"
echo "🎉 Sukces! Aplikacja została automatycznie wysłana do Google Play."
echo "👉 Wejdź za ok. 10-15 minut do Google Play Console, aby sprawdzić wersję roboczą."
echo "============================================================"
