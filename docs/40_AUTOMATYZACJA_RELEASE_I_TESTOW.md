---
type: System Documentation
title: "40. Automatyzacja Release i Testów"
description: "Opis skryptów automatyzujących dystrybucję aplikacji iOS/Android, zarządzanie kontami testerów oraz konfigurację metadanych sklepów z terminala."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/40_AUTOMATYZACJA_RELEASE_I_TESTOW.md
tags: [ai, analytics, crm, database, frontend, identity, infrastructure, ingestion, notifications, testing, android, ios, play-store, app-store]
timestamp: 2026-07-20T16:05:00+02:00
---

# 40. Automatyzacja Release i Testów

Opis skryptów automatyzujących dystrybucję aplikacji iOS oraz Android, zarządzanie kontami testerów i konfigurację metadanych w App Store Connect oraz Google Play Console. Wszystkie operacje wykonywane z terminala, bez klikania w panelach webowych (tam, gdzie to możliwe).

---

## Wymagania wstępne

### Poświadczenia Apple (App Store Connect API)

Skrypty korzystają z pliku `credentials.env` w katalogu głównym repozytorium. Plik **nie jest commitowany** (`.gitignore`). Format:

```env
APP_STORE_ISSUER_ID=<issuer-id-z-panelu-apple>
APP_STORE_KEY_ID=<key-id>
APP_STORE_PRIVATE_KEY_PATH=./AuthKey_<key-id>.p8
```

Klucz prywatny (`.p8`) musi leżeć w dwóch miejscach:
- W katalogu głównym repozytorium (dla skryptów Go).
- W `~/private_keys/` (dla `xcrun altool`, wymagane przez Apple).

> **⚠️ Klucz musi mieć rolę Admin**, aby móc zapraszać użytkowników do zespołu Apple i zarządzać wersjami. Klucze z rolą Developer/App Manager nie mają wystarczających uprawnień.

### Poświadczenia Google Play (Google API)

Wysyłka na platformę Android wymaga klucza konta usługowego (Service Account) z rolą administratora wydań w Google Play Console.
Plik klucza powinien znajdować się w głównym katalogu repozytorium pod nazwą `play-sa-key.json` (lub ścieżka zdefiniowana w `credentials.env` pod zmienną `PLAY_STORE_JSON_KEY_PATH`).

### Poświadczenia GCP (Firebase + baza danych)

Przed uruchomieniem skryptów dotyczących Firebase/bazy danych:

```bash
gcloud auth login --no-launch-browser
gcloud auth application-default login --no-launch-browser
```

Użyj przeglądarki z profilem Chrome powiązanym z kontem `superwizor-ai-25ecd`. Skrypt `KOMENDY/9` automatycznie uruchamia `cloud-sql-proxy` do tunelowania połączenia z bazą.

---

## Spis skryptów w `KOMENDY/`

| # | Skrót | Skrypt | Opis |
|---|-------|--------|------|
| 8 | `./KOMENDY/8` | `8_wyslij_testflight.sh` | Build + automatyczna wysyłka `.ipa` do TestFlight |
| 9 | `./KOMENDY/9` | `9_zarejestruj_stazystow.sh` | Rejestracja testerów w Firebase Auth + PostgreSQL |
| 10 | `./KOMENDY/10` | `10_wyslij_googleplay.sh` | Build + wysyłka `.aab` do Google Play na tor wewnętrzny (internal) |
| 11 | `./KOMENDY/11` | `11_wyslij_googleplay_live.sh` | Build + wysyłka `.aab` bezpośrednio na tor produkcyjny (production/LIVE) |

---

## 1. Rejestracja testerów (Firebase Auth + baza danych)

**Skrypt:** `superwizor-backend/scripts/seed_interns.go`  
**Uruchomienie:** `./KOMENDY/9`

### Co robi

1. Uruchamia `cloud-sql-proxy` (jeśli port 5432 jest wolny).
2. Łączy się z Firebase Auth i bazą PostgreSQL.
3. Dla każdej osoby z tablicy `interns`:
   - **Firebase Auth:** tworzy konto (lub pomija, jeśli istnieje). Hasło: zdefiniowane w zmiennej `defaultPassword` w skrypcie.
   - **Baza danych (w transakcji):**
     - Adres (placeholder Kraków).
     - Organizacja typu `SOLO` (izolacja danych między testerami).
     - Użytkownik z rolą `THERAPIST`.
     - Subskrypcja `PRO` (Rozkwit) ważna 100 lat.
     - Licznik użycia z limitem 90 tokenów/sesji.
4. Jeśli użytkownik już istnieje — aktualizuje `firebase_uid`, resetuje limit tokenów do 90 i odnawia subskrypcję.

### Jak dodać nowego testera

1. Edytuj tablicę `interns` w `superwizor-backend/scripts/seed_interns.go`:
   ```go
   interns := []Intern{
       // ... istniejące wpisy ...
       {Email: "nowy.tester@example.com", FirstName: "Jan", LastName: "Kowalski"},
   }
   ```
2. Uruchom:
   ```bash
   ./KOMENDY/9
   ```
   Skrypt jest idempotentny — bezpiecznie go uruchamiać wielokrotnie.

### Uwagi

- **DSN bazy danych** jest zahardkodowany w `9_zarejestruj_stazystow.sh` (zmienna `DATABASE_URL`). Przy rotacji hasła w Secret Manager (`postgres-database-url`) trzeba go ręcznie zaktualizować.
- Skrypt **nie dodaje** użytkowników do TestFlight ani do Apple Developer. To oddzielne kroki (patrz sekcja 3).

---

## 2. Wysyłka buildu na TestFlight (iOS)

**Skrypt:** `KOMENDY/8_wyslij_testflight.sh`  
**Uruchomienie:** `./KOMENDY/8`

### Co robi

1. `flutter clean` + `flutter pub get`.
2. `flutter build ipa` — tworzy produkcyjne archiwum `.ipa`.
3. Wczytuje `APP_STORE_KEY_ID` and `APP_STORE_ISSUER_ID` z `credentials.env`.
4. Jeśli klucz API jest dostępny → `xcrun altool --upload-app` wysyła `.ipa` bezpośrednio do TestFlight.
5. Jeśli brak klucza → otwiera `Runner.xcarchive` w Xcode Organizer jako fallback.

### Po wysyłce

- Paczka pojawi się w App Store Connect po ok. 10-15 minut przetwarzania.
- Użytkownicy dodani do grup TestFlight (wewnętrznych lub zewnętrznych) automatycznie otrzymają powiadomienie o nowej wersji.

---

## 3. Wysyłka buildu na Google Play (Android)

Do wysyłki paczek na Androida służą dwa skrypty. Pod spodem uruchamiają one skrypt Go `superwizor-backend/scripts/upload_to_play.go`.

### A. Tor Wewnętrzny (Internal Testing)
**Skrypt:** `KOMENDY/10_wyslij_googleplay.sh`  
**Uruchomienie:** `./KOMENDY/10`  
Zalecany do codziennych testów. Paczka trafia natychmiast do zdefiniowanej grupy testerów wewnętrznych.

### B. Produkcja bezpośrednia (LIVE)
**Skrypt:** `KOMENDY/11_wyslij_googleplay_live.sh`  
**Uruchomienie:** `./KOMENDY/11`  
Skrypt automatycznie wrzuca paczkę `.aab` na tor produkcyjny (`production`) ze statusem `completed` (100% rollout). 

> **⚠️ Ważna uwaga dotycząca publikacji LIVE na Androidzie:**
> Nawet po wysyłce na tor produkcyjny skryptem, aplikacja może nie pojawić się od razu w sklepie, jeżeli w Google Play Console włączona jest opcja **Zarządzane publikowanie (Managed Publishing)**. W takim wypadku paczka przechodzi weryfikację Google, ale wdrożenie na produkcję wymaga kliknięcia przycisku "Wyślij zmiany do publikacji" w panelu webowym Google Play Console. Aby publikacja z konsoli była w pełni automatyczna, należy wyłączyć opcję "Managed Publishing" w panelu.

---

## 4. Dodawanie użytkowników do Apple Developer (Users & Access)

Osoby dodane w sekcji **Users and Access** w App Store Connect (z dowolną rolą, np. Customer Support) automatycznie stają się **wewnętrznymi testerami TestFlight** i mogą pobierać buildy bez osobnego zaproszenia.

### Przez panel webowy

1. Wejdź na [App Store Connect → Users and Access](https://appstoreconnect.apple.com/access/users).
2. Kliknij `+` → podaj email, imię, nazwisko, zaznacz rolę **Customer Support** → **Invite**.

### Przez API (wymaga klucza Admin)

Endpoint: `POST /v1/userInvitations`

```json
{
  "data": {
    "type": "userInvitations",
    "attributes": {
      "email": "nowy@example.com",
      "firstName": "Jan",
      "lastName": "Kowalski",
      "roles": ["CUSTOMER_SUPPORT"],
      "allAppsVisible": true
    }
  }
}
```

> **Uwaga:** Klucz API must mieć rolę **Admin**. Klucz z rolą Developer zwróci `403 FORBIDDEN_ERROR.ROLES_NOT_ALLOWED`.

---

## 5. Automatyzacja metadanych App Store Connect

**Skrypt:** `superwizor-backend/scripts/update_app_metadata.go`  
**Uruchomienie:** `cd superwizor-backend && go run scripts/update_app_metadata.go`

### Co aktualnie robi

| Operacja | Endpoint API | Opis |
|----------|-------------|------|
| Tworzenie wersji | `POST /v1/appStoreVersions` | Tworzy nową wersję w sklepie, jeśli nie istnieje |
| Zmiana kategorii | `PATCH /v1/appInfos/{id}` | Ustawia kategorie ( Productivity + Health & Fitness) |
| WhatsNew (Co nowego) | `PATCH /v1/appStoreVersionLocalizations/{id}` | Aktualizuje opisy zmian per lokalizacja (pl, en-US) |

### Co jeszcze można zautomatyzować (rozbudowa skryptu)

- Przypisanie buildu z TestFlight do wersji App Store.
- Wysyłka do Apple Review (`Submit for Review`).

---

## Typowy flow wydania nowej wersji produkcyjnej

### Android (Google Play)
1. Podnieś wersję w `pubspec.yaml` (np. `1.0.1+25` -> `1.0.2+26`).
2. `./KOMENDY/11` (buduje AAB i wysyła bezpośrednio na tor produkcyjny).
3. Jeśli masz wyłączone "Managed Publishing", wersja wejdzie automatycznie do sklepu po przejściu review w Google.

### iOS (App Store)
1. Podnieś wersję w `pubspec.yaml`.
2. `./KOMENDY/8` (buduje IPA i wysyła do TestFlight).
3. Uruchom `go run scripts/update_app_metadata.go` (tworzy nową wersję roboczą i ustawia WhatsNew).
4. **Krok ręczny:** Ponieważ przetworzenie buildu na serwerach Apple trwa 15-30 minut, podpięcie go pod wersję roboczą i wysłanie do recenzji (`Submit for Review`) aktualnie wymaga kliknięcia w App Store Connect.

---

## Typowy flow dodania nowego testera

```
1. Edytuj tablicę interns w seed_interns.go
2. ./KOMENDY/9                    ← konto Firebase + baza danych
3. Dodaj osobę w Users & Access   ← panel Apple lub API (sekcja 4)
4. Osoba dostaje maila od Apple, pobiera TestFlight, loguje się hasłem z seed_interns.go
```
