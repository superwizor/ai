# 40. Automatyzacja Release i Testów

Opis skryptów automatyzujących dystrybucję aplikacji iOS, zarządzanie kontami testerów oraz konfigurację metadanych App Store Connect. Wszystkie operacje wykonywane z terminala, bez klikania w panelach webowych.

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

## 2. Wysyłka buildu na TestFlight

**Skrypt:** `KOMENDY/8_wyslij_testflight.sh`  
**Uruchomienie:** `./KOMENDY/8`

### Co robi

1. `flutter clean` + `flutter pub get`.
2. `flutter build ipa` — tworzy produkcyjne archiwum `.ipa`.
3. Wczytuje `APP_STORE_KEY_ID` i `APP_STORE_ISSUER_ID` z `credentials.env`.
4. Jeśli klucz API jest dostępny → `xcrun altool --upload-app` wysyła `.ipa` bezpośrednio do TestFlight.
5. Jeśli brak klucza → otwiera `Runner.xcarchive` w Xcode Organizer jako fallback.

### Po wysyłce

- Paczka pojawi się w App Store Connect po ok. 10-15 minut przetwarzania.
- Użytkownicy dodani do grup TestFlight (wewnętrznych lub zewnętrznych) automatycznie otrzymają powiadomienie o nowej wersji.

---

## 3. Dodawanie użytkowników do Apple Developer (Users & Access)

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

> **Uwaga:** Klucz API musi mieć rolę **Admin**. Klucz z rolą Developer zwróci `403 FORBIDDEN_ERROR.ROLES_NOT_ALLOWED`.

---

## 4. Automatyzacja metadanych App Store Connect

**Skrypt:** `superwizor-backend/scripts/update_app_metadata.go`  
**Uruchomienie:** `cd superwizor-backend && go run scripts/update_app_metadata.go`

### Co aktualnie robi

| Operacja | Endpoint API | Opis |
|----------|-------------|------|
| Tworzenie wersji | `POST /v1/appStoreVersions` | Tworzy nową wersję (np. `1.0.1`), jeśli nie istnieje |
| Zmiana kategorii | `PATCH /v1/appInfos/{id}` | Ustawia kategorie (aktualnie: Productivity + Health & Fitness) |
| WhatsNew (Co nowego) | `PATCH /v1/appStoreVersionLocalizations/{id}` | Aktualizuje opisy zmian per lokalizacja (pl, en-US) |

### Co jeszcze można zautomatyzować (rozbudowa skryptu)

- Przypisanie buildu z TestFlight do wersji App Store.
- Wysyłka do Apple Review (`Submit for Review`).
- Zarządzanie cenami i In-App Purchases.
- Zarządzanie screenshotami i preview wideo.

---

## Typowy flow wydania nowej wersji

```
1. Podnieś wersję w pubspec.yaml (np. 1.0.1+25 → 1.0.2+26)
2. ./KOMENDY/8                    ← build + upload do TestFlight
3. (Opcjonalnie) go run scripts/update_app_metadata.go  ← WhatsNew, kategorie
4. W App Store Connect: wybierz build, Submit for Review
```

---

## Typowy flow dodania nowego testera

```
1. Edytuj tablicę interns w seed_interns.go
2. ./KOMENDY/9                    ← konto Firebase + baza danych
3. Dodaj osobę w Users & Access   ← panel Apple lub API (sekcja 3)
4. Osoba dostaje maila od Apple, pobiera TestFlight, loguje się hasłem z seed_interns.go
```
