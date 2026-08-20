#!/usr/bin/env bash
# 8_wyslij_testflight.sh
set -e

# Ścieżki rozstrzygane PRZED cd i jako bezwzględne.
#
# Wcześniej ENV_FILE liczono przez `dirname "$0"` DOPIERO PO zmianie
# katalogu, więc przy wywołaniu ścieżką względną (./KOMENDY/8_...)
# skrypt szukał credentials.env w flutter-app/superwizor/KOMENDY/../ —
# tam, gdzie go nie ma. Efekt: cicho wchodził w gałąź "brak klucza API",
# budował IPA i otwierał Xcode Organizer zamiast wysłać paczkę.
# Wyglądało to na sukces (kod wyjścia 0), a wysyłka się nie odbywała.
# Zdarzyło się 13.08.2026.
KATALOG_SKRYPTU="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# credentials.env szukany w obu sensownych miejscach: w katalogu repo i
# poziom wyzej. Do 20.08.2026 sprawdzane bylo tylko to pierwsze, a plik
# lezal w drugim — czyli dokladnie ten sam tryb awarii, ktory opisuje
# komentarz powyzej, przesuniety o jeden katalog. Skrypt wchodzil wtedy
# w galaz "brak klucza API" albo szedl na zmienne ze srodowiska.
ENV_FILE=""
for KANDYDAT in "$KATALOG_SKRYPTU/../credentials.env" "$KATALOG_SKRYPTU/../../credentials.env"; do
    if [ -f "$KANDYDAT" ]; then
        ENV_FILE="$KANDYDAT"
        echo "🔑 Konfiguracja API: $ENV_FILE"
        break
    fi
done
if [ -z "$ENV_FILE" ]; then
    echo "⚠️  Nie znaleziono credentials.env w zadnej ze sprawdzanych lokalizacji."
fi

echo "🚀 Przygotowanie wersji do TestFlight..."
cd "$KATALOG_SKRYPTU/../flutter-app/superwizor"

echo "🧹 1. Czyszczenie starych buildów..."
flutter clean
flutter pub get

echo "📦 2. Budowanie paczki IPA dla iOS..."
# --export-options-plist wskazuje NASZ plik zamiast generowanego przez
# Fluttera. Jedyna różnica, która ma znaczenie:
# manageAppVersionAndBuildNumber=false.
#
# Bez tego Xcode podbija numer builda przy eksporcie i paczka niesie inny
# numer niż pubspec.yaml — tak 14.08.2026 do testerów pojechał build 41,
# podczas gdy repozytorium twierdziło 40. Numer builda rozstrzyga, którą
# wersję ma użytkownik, więc musi mieć jedno źródło prawdy.
flutter build ipa --export-options-plist=ios/ExportOptions.plist

# Wczytanie konfiguracji z credentials.env jeśli istnieje
if [ -f "$ENV_FILE" ]; then
    # Zakotwiczone na poczatku linii i z ograniczeniem do pierwszego
    # trafienia. Gole `grep NAZWA` lapie takze komentarze, ktore te nazwe
    # wymieniaja — 20.08.2026 komentarz z przykladem uzycia
    # ($APP_STORE_ISSUER_ID) trafil przed prawdziwa wartosc i altool
    # dostal sklejke, a wysylka zwrocila 401 wygladajace jak zly klucz.
    APP_STORE_ISSUER_ID=$(grep -m1 '^APP_STORE_ISSUER_ID=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r' | tr -d ' ')
    APP_STORE_KEY_ID=$(grep -m1 '^APP_STORE_KEY_ID=' "$ENV_FILE" | cut -d'=' -f2- | tr -d '\r' | tr -d ' ')
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
    echo "🖥️ 3. Otwieranie Archiwum w Xcode Organizer."
    echo "   Powód: nie znaleziono kompletu APP_STORE_ISSUER_ID/APP_STORE_KEY_ID"
    echo "   w pliku: $ENV_FILE"
    open build/ios/archive/Runner.xcarchive
    
    echo "============================================================"
    echo "🎉 Xcode Organizer został otwarty!"
    echo "👉 Kliknij niebieski przycisk 'Distribute App' po prawej stronie, aby wysłać aplikację do TestFlight."
    echo "============================================================"
fi
