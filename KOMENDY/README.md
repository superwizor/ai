# 🎛️ PORTAL KOMENDY - SuperWizor AI

Witaj w centrum dowodzenia! Ten folder zawiera proste skrypty uruchomieniowe (skróty), dzięki którym nie musisz pamiętać długich komend konsolowych ani zmiennych środowiskowych. 

Wystarczy wejść do tego katalogu w terminalu i uruchomić odpowiedni skrypt, bądź uruchomić go dwukrotnym kliknięciem (lub przeciągnięciem do terminala).

---

## 📋 Spis Dostępnych Skrótów

Każdy skrypt wykonuje jedną konkretną czynność deweloperską. Możesz ich używać wpisując sam numer (np. `./KOMENDY/1`) lub pełną nazwę:

| # | Komenda (krótka) | Skrypt (pełny) | Opis działania | Kiedy używać? |
| :--- | :--- | :--- | :--- | :--- |
| **1** | `./KOMENDY/1` | `1_odpal_backend_lokalnie.sh` | Uruchamia lokalne migracje i włącza w tle wszystkie 5 mikrousług na Twoim Macu. Logi zapisują się w katalogu `logs/`. | Gdy chcesz programować lokalnie lub odpalić testy E2E. |
| **2** | `./KOMENDY/2` | `2_odpal_testy_e2e_lokalnie.sh` | Uruchamia pełny zestaw testów integracyjnych E2E bazy i logiki skierowany na lokalnie uruchomione usługi (`localhost`). | Przed commitem lub po zmianach w logice bazodanowej/RODO. |
| **3** | `./KOMENDY/3` | `3_uruchom_apke_mac.sh` | Uruchamia aplikację deweloperską Flutter jako natywną aplikację na system macOS. | Do szybkiego programowania wyglądu i logiki UI bez telefonu. |
| **4** | `./KOMENDY/4` | `4_wgraj_apke_na_telefon.sh` | Uruchamia aplikację i pyta, na które z podłączonych kablem urządzeń fizycznych (iPhone/Android) ją wgrać. | Do testowania nagrywania audio i rzeczywistego działania na telefonie. |
| **5** | `./KOMENDY/5` | `5_zbuduj_i_otworz_xcode.sh` | Buduje wersję produkcyjną aplikacji dla iOS (tworzy plik `.ipa`) i automatycznie otwiera Xcode, skąd wysyłamy wersję do App Store. | Gdy chcesz wypuścić nową wersję do TestFlight / Apple Store. |
| **6** | `./KOMENDY/6` | `6_uruchom_www_lokalnie.sh` | Odpala lokalny serwer dla strony marketingowej WWW i automatycznie otwiera adres `http://localhost:3000` w przeglądarce Chrome. | Gdy edytujesz stronę główną lub podstronę rejestracji terapeuty. |

---

## 🛠️ Jak z tego korzystać? (Instrukcja Krok po Kroku)

### Scenariusz A: Chcę lokalnie przetestować i sprawdzić działanie aplikacji
1. Otwórz **Terminal nr 1** i wpisz:
   ```bash
   ./KOMENDY/1
   ```
   *(Zostaw to okno otwarte – na bieżąco będą się tu wyświetlać logi z usług).*
2. Podłącz telefon kablem do Maca (lub odblokuj symulator) i w **Terminalu nr 2** wpisz:
   ```bash
   ./KOMENDY/4
   ```
   *(Aplikacja uruchomi się na Twoim telefonie, łącząc się z bazą danych na Twoim komputerze).*

---

### Scenariusz B: Chcę wypuścić nową wersję do Apple App Store (TestFlight)
1. Upewnij się, że nie masz żadnych błędów kompilacji, a potem w terminalu wpisz:
   ```bash
   ./KOMENDY/5_zbuduj_i_otworz_xcode.sh
   ```
2. Skrypt zbuduje paczkę iOS i otworzy Xcode.
3. W Xcode u góry wybierz menu **Product -> Archive**.
4. Po ukończeniu archiwizacji otworzy się okno *Organizer* – kliknij tam **niebieski przycisk "Distribute App"** po prawej stronie i przeklikaj kreator wysyłki do App Store Connect.

---

### Scenariusz C: Chcę edytować stronę główną www i sprawdzić ją w przeglądarce
1. Wpisz w terminalu:
   ```bash
   ./KOMENDY/6_uruchom_www_lokalnie.sh
   ```
2. Automatycznie otworzy się przeglądarka z adresem `http://localhost:3000`. Każda edycja kodu strony będzie natychmiast widoczna na ekranie (Hot Reload).

---

> 💡 **Wskazówka Seniora**: Jeśli po wywołaniu skryptu otrzymasz błąd o braku uprawnień (Permission Denied), nadaj uprawnienia wszystkim skryptom wpisując raz w głównym katalogu: `chmod +x KOMENDY/*.sh`
