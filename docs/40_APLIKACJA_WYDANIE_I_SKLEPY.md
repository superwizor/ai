---
type: System Documentation
title: "40. Wydanie aplikacji w sklepach (App Store & Google Play)"
description: "Dokument zawiera kompletną konfigurację, teksty marketingowe, dane konta testowego oraz procedury związane z wydaniem aplikacji SuperWizor AI w sklepach mobi..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/40_APLIKACJA_WYDANIE_I_SKLEPY.md
tags: [ai, analytics, crm, database, frontend, identity, infrastructure, ingestion, notifications, security, testing]
timestamp: 2026-06-26T18:05:07+02:00
---

# 40. Wydanie aplikacji w sklepach (App Store & Google Play)

Dokument zawiera kompletną konfigurację, teksty marketingowe, dane konta testowego oraz procedury związane z wydaniem aplikacji SuperWizor AI w sklepach mobilnych.

---

## 🍏 Część 1: Apple App Store (iOS)

### 1.1 Status pierwszej publikacji (Wersja 1.0.0)
*   **Wydanie:** `1.0.0`
*   **Kompilacja (Build):** `11`
*   **Aktualny status:** `Waiting for Review` (Oczekuje na recenzję)
*   **Metoda wydania:** Ręczna (Manually release this version) po zatwierdzeniu przez Apple.

### 1.2 Dane konta testowego dla Apple Review (App Review Information)
Apple wymaga działającego konta do przetestowania aplikacji. Dane zostały weryfikowane w bazie Firebase (`emailVerified: true`).
*   **Adres e-mail:** `apple-test2@superwizor.ai`
*   **Hasło:** `SuperwizorApple2026!`
*   **Notatka dla weryfikatora (Notes):**
    ```text
    This application is a tool for psychotherapists to securely record sessions and review summary reports.

    To test the main functionality:
    1. Log in with the provided test credentials.
    2. Select a test client from the list or create a new one.
    3. Press the record button and record a sample conversation (e.g. speak for 2 minutes).
    4. Stop the recording and wait for the upload to complete.
    5. The application will securely process the audio and generate a sample session summary.
    ```
*   **Kontakt dla Apple:** Maciej Kołodziejczyk (`+48510417781` / `maciej@euphire.pl`).

### 1.3 Teksty i metadane do App Store (Zgodne z Brand Voice - md 32)

#### 🇵🇱 Wersja Polska (Polish)
*   **Nazwa (Name):** `SuperWizor AI`
*   **Podtytuł (Subtitle):** `Poznawczy partner w gabinecie`
*   **Tekst promocyjny (Promotional Text):**
    ```text
    Poznawczy partner w Twoim gabinecie. Uwalnia przestrzeń mentalną między spotkaniami i pozwala w pełni skupić się na kliencie.
    ```
*   **Opis (Description):**
    ```text
    Superwizor AI to poznawczy partner w gabinecie psychoterapeuty. Aplikacja wspiera specjalistów zdrowia psychicznego w utrzymaniu ciągłości procesu i uwalnia przestrzeń mentalną między spotkaniami.

    Zamiast nosić w pamięci szczegóły każdej sesji, możesz w pełni skupić się na obecności i uważności podczas pracy z klientem. Po naciśnięciu przycisku „stop” praca naprawdę się kończy, a podsumowanie spotkania czeka na Ciebie gotowe.

    Jak działa Superwizor AI:
    - Włączasz nagrywanie jednym tapnięciem przed rozpoczęciem sesji i jesteś w pełni obecny dla klienta.
    - Wracasz do dowolnej wypowiedzi w kilka sekund – sesja staje się czytelnym zapisem z neutralnym podziałem na role mówców.
    - Otrzymujesz esencję spotkania, wątki i obserwacje przygotowane zgodnie z Twoim nurtem terapeutycznym.
    - Narzędzia ułatwiają śledzenie, jak proces z klientem rozwija się w czasie.

    Zaufanie i poufność:
    Zaufanie zbudowane w gabinecie jest dla nas najważniejsze. Dane są chronione za pomocą zaawansowanych zabezpieczeń:
    - Wszystkie dane są przetwarzane na bezpiecznych serwerach na terenie Unii Europejskiej, w pełnej zgodności z RODO i DPA.
    - Pliki audio sesji są bezpowrotnie usuwane po transkrypcji (najpóźniej po 48 godzinach).
    - Zastosowaliśmy pełne szyfrowanie danych (szyfrowanie kopertowe i Google Cloud KMS).
    - Nie trenujemy sztucznej inteligencji na Twoich danych ani na treściach sesji.
    ```
*   **Słowa kluczowe (Keywords):** `psychoterapia,terapeuta,notatki kliniczne,transkrypcja,psychologia,asystent,rodo,medycyna,hitop`
*   **Adresy URL:**
    *   *Support URL (Wsparcie):* `https://superwizor.ai/pl/kontakt/`
    *   *Privacy Policy URL (Prywatność):* `https://superwizor.ai/pl/legal/privacy`

#### 🇺🇸 Wersja Angielska (English U.S.)
*   **Nazwa (Name):** `SuperWizor AI`
*   **Podtytuł (Subtitle):** `Cognitive partner in the office`
*   **Tekst promocyjny (Promotional Text):**
    ```text
    A cognitive partner in your office. Superwizor AI frees up mental space between sessions and helps maintain continuity with your clients.
    ```
*   **Opis (Description):**
    ```text
    Superwizor AI is a cognitive partner in the psychotherapist's office. The application supports mental health professionals in maintaining process continuity and frees up mental space between sessions.

    Instead of carrying the details of every session in your memory, you can fully focus on presence and mindfulness while working with your client. When you press the "stop" button, the work truly ends, and the session summary is ready and waiting for you.

    How Superwizor AI works:
    - Start recording with a single tap before the session begins and remain fully present for your client.
    - Return to any statement in seconds – the session becomes a clear record with neutral speaker labels.
    - Receive the essence of the meeting, themes, and observations tailored to your therapeutic modality.
    - Tools make it easy to track how the process with your client develops over time.

    Trust and Confidentiality:
    The trust built in the office is our top priority. Your data is protected by advanced security measures:
    - All data is processed on secure servers within the European Union, in full compliance with GDPR and DPA.
    - Session audio files are permanently deleted after transcription (within 48 hours at the latest).
    - We implement full data encryption (envelope encryption and Google Cloud KMS).
    - We do not train artificial intelligence on your data or session content.
    ```
*   **Słowa kluczowe (Keywords):** `psychotherapy,therapist,clinical notes,transcription,psychology,assistant,gdpr,medicine,hitop`
*   **Adresy URL:**
    *   *Support URL (Wsparcie):* `https://superwizor.ai`
    *   *Privacy Policy URL (Prywatność):* `https://superwizor.ai/legal/privacy`

### 1.4 Grafiki i Zrzuty Ekranu (Screenshots)
Apple wymaga zrzutów ekranu dla zadeklarowanych platform. Wygenerowaliśmy dedykowane plansze marketingowe oparte na Twoich oryginalnych plikach z folderu `Downloads/SuperwizorScreenshots`.

| Platforma | Wymagany Rozmiar (px) | Wygenerowany katalog docelowy |
| :--- | :--- | :--- |
| **iPhone (6.5")** | `1284 x 2778` | `Downloads/Superwizor_iPhoneScreenshots/` |
| **iPad (13")** | `2048 x 2732` | `Downloads/Superwizor_iPadScreenshots/` |

#### Skrypt automatycznie skalujący/docinający plansze marketingowe (do ponownego użycia):
Skrypt docina grafiki ze środka (crop-to-fit) do idealnej rozdzielczości iPada / iPhone'a:
```bash
# Uruchomienie dla iPada:
python3 make_ipad_marketing.py

# Uruchomienie dla iPhone'a:
python3 make_iphone_marketing.py
```

---

## 🤖 Część 2: Google Play Store (Android)

### 2.1 Status pierwszej publikacji
*   **Wydanie:** `1.0.0+9`
*   **Application ID:** `ai.superwizor.superwizor`
*   **Target SDK:** `35` (Android 15)
*   **Min SDK:** Zarządzany przez Flutter (`flutter.minSdkVersion`)
*   **Plik produkcyjny:** `build/app/outputs/bundle/release/app-release.aab` (58.5 MB)
*   **Komenda budowania:**
    ```bash
    cd flutter-app/superwizor
    flutter build appbundle
    ```

---

### 2.2 Dane do weryfikacji aplikacji (App Access / Sign in details)
Google Play Console wymaga podania danych testowych w zakładce **Polityka i treść** → **Dostęp do aplikacji**:
*   **📧 Nazwa użytkownika:** `demo@superwizor.ai`
*   **🔐 Hasło:** `SuperwizorDemo123!`
*   **📝 Instrukcja (Parameters):** Dokładnie ta sama, co dla Apple (Krok 1.2).

---

### 2.3 Ikona aplikacji (Adaptive Icon)
Android korzysta z systemu **Adaptive Icons** (API 26+), który dzieli ikonę na dwie warstwy: tło i pierwszy plan (foreground).

**Źródło ikony:** `assets/Ico/Logo_Superwizor_MVP.png`

**Konfiguracja w projekcie:**
*   **Plik XML adaptive icon:** `android/app/src/main/res/mipmap-anydpi-v26/launcher_icon.xml`
    ```xml
    <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
      <background android:drawable="@color/ic_launcher_background"/>
      <foreground>
          <inset
              android:drawable="@drawable/ic_launcher_foreground"
              android:inset="16%" />
      </foreground>
    </adaptive-icon>
    ```
*   **Foreground drawable:** `ic_launcher_foreground` — wygenerowany z `Logo_Superwizor_MVP.png` i umieszczony w folderach `drawable-*dpi`.
*   **Background color:** Zdefiniowany w `values/ic_launcher_background.xml` (kolor jednorodny, aby ikona była spójna na każdym launcherze).
*   **Inset 16%** — logo jest lekko zmniejszone, aby system Android miał miejsce na maskę (okrągłą, squircle, kwadratową itp.) bez obcinania grafiki.

**Pliki rastrowe (mipmap):** Ikona `launcher_icon.png` jest wygenerowana w rozdzielczościach:
| Folder | Rozmiar |
| :--- | :--- |
| `mipmap-mdpi` | 48×48 px |
| `mipmap-hdpi` | 72×72 px |
| `mipmap-xhdpi` | 96×96 px |
| `mipmap-xxhdpi` | 144×144 px |
| `mipmap-xxxhdpi` | 192×192 px |

**Manifest:** `android:icon="@mipmap/launcher_icon"` w tagu `<application>`.

> ⚠️ **Uwaga:** Plik `Logo_Superwizor_MVP_foreground.png` (osobny foreground) **NIE jest używany**. Jedynym źródłem ikony jest `Logo_Superwizor_MVP.png`.

---

### 2.4 Ikona powiadomień (Notification Icon)
Android wymaga specjalnej, jednokolorowej (białej z przezroczystym tłem) ikony do powiadomień na pasku statusu.

*   **Plik:** `android/app/src/main/res/drawable/ic_stat_notification.xml` — wektorowy drawable (VectorDrawable) wygenerowany jako biała sylwetka logo Superwizora.
*   **Użycie:** W `RecordingForegroundService.kt` ustawiony jako `.setSmallIcon(R.drawable.ic_stat_notification)`.
*   Dzięki temu na pasku statusu Android wyświetla się czytelna, biała ikonka Superwizora zamiast domyślnej ikony systemowej.

---

### 2.5 Widget ekranu głównego (Home Screen Widget)
Aplikacja posiada natywny widget Android, który wyświetla aktywną sesję nagrywania na ekranie głównym telefonu.

**Pliki implementacji:**
| Plik | Opis |
| :--- | :--- |
| `ActiveSessionWidgetProvider.kt` | Kotlin AppWidgetProvider obsługujący logikę widgetu (start/update/stop/click intent) |
| `res/layout/active_session_widget.xml` | Układ XML widgetu (logo, nazwa sesji, stoper, dioda nagrywania) |
| `res/drawable/widget_background.xml` | Ciemne tło z gradientem Evergreen→Nocturne (#004D54→#002E32) i zaokrąglonymi rogami 16dp |
| `res/drawable/widget_dot.xml` | Okrągła, czerwona dioda nagrywania |
| `res/xml/active_session_widget_info.xml` | Metadane widgetu (rozmiar, preview, update period) |

**Stany widgetu:**
1.  **Bezczynność (Idle):** Wyświetla nagłówek „Superwizor AI" i status „Brak aktywnej sesji". Kliknięcie otwiera aplikację.
2.  **Aktywna sesja:** Wyświetla nazwę klienta, stoper czasu, tętniącą czerwoną diodę nagrywania. Kliknięcie otwiera ekran nagrywania.

**Deklaracja w AndroidManifest.xml:**
```xml
<receiver android:name=".ActiveSessionWidgetProvider" android:exported="true">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data android:name="android.appwidget.provider"
               android:resource="@xml/active_session_widget_info" />
</receiver>
```

---

### 2.6 Uprawnienia i Foreground Service
Pełna lista uprawnień zadeklarowanych w `AndroidManifest.xml`:

| Uprawnienie | Cel |
| :--- | :--- |
| `INTERNET` | Komunikacja sieciowa (Firebase, GCS, gRPC) — dodane do manifestu głównego, nie tylko debug |
| `RECORD_AUDIO` | Nagrywanie sesji terapeutycznych |
| `WAKE_LOCK` | Utrzymanie procesora aktywnego podczas nagrywania w tle |
| `FOREGROUND_SERVICE` | Uruchomienie usługi na pierwszym planie |
| `FOREGROUND_SERVICE_MICROPHONE` | Android 14+: deklaracja typu FGS microphone |
| `POST_NOTIFICATIONS` | Android 13+: wymagane, aby powiadomienie FGS było widoczne |

**Foreground Service:**
```xml
<service android:name=".RecordingForegroundService"
         android:exported="false"
         android:foregroundServiceType="microphone" />
```
Usługa `RecordingForegroundService.kt` wyświetla trwałe powiadomienie informujące użytkownika o aktywnym nagrywaniu sesji. Kontrolowana z Darta przez MethodChannel `superwizor/recording_fgs`.

---

### 2.7 Deklaracja FOREGROUND_SERVICE_MICROPHONE w Google Play Console

W zakładce **Foreground service permissions** w Google Play Console:

#### Zaznaczone zadania:
*   ☑️ **Background audio input**
*   ☑️ **Other**

#### Tekst uzasadnienia (do wklejenia):
```text
Superwizor AI is a clinical session co-pilot designed for psychotherapists. The application allows therapists to securely record their clinical sessions, which typically last between 45 and 60 minutes.

During these long sessions, the therapist must be able to lock their device, turn off the screen, or temporarily background the app (for example, to consult client files or treatment notes) without interrupting the audio capture. The FOREGROUND_SERVICE_MICROPHONE permission is crucial to prevent the Android operating system from suspending or killing the recording process when the app is not in the foreground. Preventing data loss is of critical medical importance as these recordings contain essential therapy process details.

The foreground service displays a persistent, non-dismissible notification to the user, ensuring they are fully aware at all times that the microphone is actively recording and the service is running in the background.
```

---

### 2.8 Film weryfikacyjny (Video Link) — instrukcja nagrania

Google wymaga krótkiego filmu demonstrującego działanie mikrofonu w tle. Film wgrywamy na YouTube (jako niepubliczny) lub Dysk Google (dostęp: „Każdy mający link") i wklejamy link w polu **Video link**.

**Scenariusz krok po kroku:**

| # | Co zrobić | Co pokazać na ekranie |
| :---: | :--- | :--- |
| 1 | Otwórz aplikację Superwizor AI | Ekran główny / lista klientów (jesteś zalogowany) |
| 2 | Wybierz dowolnego klienta (np. „Demo") i kliknij **Rozpocznij nagrywanie** | Ekran nagrywania: widoczny timer 00:00, czerwona kropka |
| 3 | Poczekaj 5–10 sek. aż timer zacznie naliczać | Timer: 00:05, 00:10... |
| 4 | Wyjdź na pulpit (HOME) | Ekran główny telefonu |
| 5 | ⭐ Rozwiń szufladę powiadomień z góry | **Trwałe powiadomienie Superwizora** o aktywnym nagrywaniu + **zielona ikonka mikrofonu** w pasku statusu |
| 6 | *(Opcjonalnie)* Zablokuj ekran na 3 sek. i odblokuj | Powiadomienie nadal widoczne, timer działa |
| 7 | Kliknij powiadomienie lub otwórz aplikację | Ekran nagrywania: timer nieprzerwanie nalicza (np. 00:45) |
| 8 | Kliknij **Zatrzymaj nagrywanie** | Sesja zatrzymana, upload się rozpoczyna |

> 💡 **Wskazówka:** Na emulatorze Android powiadomienia mogą być domyślnie zablokowane. Przytrzymaj ikonę aplikacji → App Info → Notifications → **Allow notifications**.

---

### 2.9 Wymagane grafiki w Google Play Console

| Typ | Wymiary | Uwagi |
| :--- | :--- | :--- |
| **Ikona aplikacji** | 512 × 512 px | PNG 32-bit, maks. 1 MB |
| **Feature Graphic** | 1024 × 500 px | JPG lub 24-bit PNG, góra karty katalogowej |
| **Zrzuty ekranu telefonu** | min. 2, maks. 8 | 16:9 lub 9:16; np. `1080×2400` lub `1284×2778` z iPhone'a |
| **Zrzuty ekranu tabletu** | 7" i 10" | Opcjonalne; można użyć plansz wygenerowanych dla iPada |

---

### 2.10 Teksty marketingowe Google Play
*   **Nazwa aplikacji:** `SuperWizor AI` (maks. 30 znaków)
*   **Krótki opis:** `Poznawczy partner w gabinecie psychoterapeuty.` (maks. 80 znaków)
*   **Pełny opis:** *(Ten sam opis co w sekcji 1.3, maksymalnie 4000 znaków).*

---

### 2.11 Audyt techniczny Android (wykonany 2026-06-26)

Przeprowadzono pełny audyt zgodności z wymaganiami Google Play:

| Krok | Status | Opis |
| :--- | :---: | :--- |
| Uprawnienie `INTERNET` w manifestie głównym | ✅ | Dodane (wcześniej tylko w debug/profile) |
| Uprawnienia mikrofonu i FGS | ✅ | `RECORD_AUDIO`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MICROPHONE`, `POST_NOTIFICATIONS` |
| Target SDK | ✅ | `targetSdk = 35` w `build.gradle.kts` |
| App Check / Play Integrity | ⏳ | Nie aktywowane — czeka na rejestrację platformy (ADR w AGENTS.md) |
| ProGuard / R8 | ✅ | Brak `minifyEnabled`, brak konfliktów refleksji |

---

### 2.12 Automatyzacja wydań z terminala (Google Play API)

Zaimplementowano w pełni zautomatyzowaną wysyłkę paczek `.aab` bezpośrednio na ścieżkę **testów wewnętrznych (internal)** za pomocą autorskiego skryptu Go, który rozmawia bezpośrednio z Google Play Developer API.

#### Uruchamianie
Wszystko jest zintegrowane w postaci wygodnego skrótu terminalowego:
```bash
./KOMENDY/10
```
Skrypt ten automatycznie uruchamia `flutter build appbundle --release`, pobiera poświadczenia sesji i wywołuje skrypt pomocniczy w katalogu backendu:
```bash
cd superwizor-backend && go run scripts/upload_to_play.go -token $(gcloud auth application-default print-access-token --scopes=https://www.googleapis.com/auth/androidpublisher)
```

#### Architektura uwierzytelniania (Bezpieczeństwo i Zero Trust)
Z uwagi na restrykcyjną politykę bezpieczeństwa Google Cloud (zakaz pobierania statycznych kluczy JSON dla kont serwisowych - `constraints/iam.disableServiceAccountKeyCreation`), mechanizm uwierzytelniania opiera się na **podszywaniu się pod konto serwisowe (Service Account Impersonation)** przy użyciu poświadczeń aktywnych w `gcloud` (ADC):

1. **Konto serwisowe:** W GCP utworzono konto `google-play-deployer@superwizor-ai-25ecd.iam.gserviceaccount.com`.
2. **Uprawnienia w Google Play Console:** Konto to zostało dodane jako użytkownik w konsoli Google Play (**Users and permissions**) z pełnym dostępem do aplikacji `ai.superwizor.superwizor` i rolą **Release manager** (Kierownik wydań).
3. **Uprawnienia IAM:** Użytkownik deweloperski `kontakt@superwizor.ai` otrzymał rolę `Service Account Token Creator` na projekcie GCP, co pozwala mu na bezpieczne generowanie tokenów w imieniu tego konta serwisowego.
4. **Konfiguracja lokalna (jednorazowa):**
   ```bash
   # Zalogowanie z dostępem do API Google Play:
   gcloud auth application-default login --scopes=https://www.googleapis.com/auth/androidpublisher,https://www.googleapis.com/auth/cloud-platform
   
   # Włączenie podszywania pod konto serwisowe:
   gcloud config set auth/impersonate_service_account google-play-deployer@superwizor-ai-25ecd.iam.gserviceaccount.com
   ```

---

## ⚠️ Część 3: Rozwiązywanie typowych problemów (Troubleshooting)

### 3.1 Brak przycisku wyboru buildu w App Store Connect
**Problem:** W sekcji *Build* na stronie wersji nie ma plusa `+` i nie można wskazać buildu z TestFlight.
**Rozwiązanie:** 
1.  Upewnij się, czy wersja w polu *Version* w App Store Connect (np. `1.0.0`) zgadza się z numerem wersji w buildzie TestFlight.
2.  Sprawdź w zakładce TestFlight, czy build nie ma statusu **Missing Compliance** (Brak zgodności eksportowej). Jeśli tak, kliknij w komunikat, zaznacz **No** w pytaniu o szyfrowanie i zapisz. Status zmieni się na *Ready to Submit*, a przycisk `+` powróci na stronie wersji.

### 3.2 Błąd "The file type/extension does not match" przy Routing App Coverage File
**Problem:** Czerwony komunikat blokujący przycisk *Add for Review*.
**Rozwiązanie:** Pole to służy wyłącznie do wgrywania plików `.geojson` dla aplikacji z mapami/nawigacją. Jeśli wgrano tam zły plik (np. obrazek), Apple zablokuje formularz. Należy kliknąć przycisk **Delete** pod plikiem, aby całkowicie wyczyścić to pole.
