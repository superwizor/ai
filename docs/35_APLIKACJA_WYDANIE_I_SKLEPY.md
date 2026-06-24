# 35. Wydanie aplikacji w sklepach (App Store & Google Play)

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

*Wydanie na Androida będzie realizowane w kolejnym kroku. Poniżej znajduje się szablon przygotowawczy.*

### 2.1 Wymagane grafiki w Google Play Console
W przeciwieństwie do Apple, Google ma bardziej elastyczne wymogi rozdzielczości, ale wymaga plansz na różne typy urządzeń:

1.  **Ikona aplikacji:** `512 x 512 px` (format PNG 32-bit z przezroczystością, maks. 1 MB).
2.  **Grafika informacyjna (Feature Graphic):** `1024 x 500 px` (format JPG lub 24-bit PNG, na samej górze karty katalogowej).
3.  **Zrzuty ekranu telefonu (Phone Screenshots):**
    *   Minimum 2 zrzuty ekranu, maksymalnie 8.
    *   Proporcje 16:9 lub 9:16.
    *   Rozmiar: od `320 px` do `3840 px` (np. format `1080 x 2400 px` lub Twoje `1284 x 2778 px` z iPhone'a również zostaną bez problemu zaakceptowane przez Google!).
4.  **Zrzuty ekranu tabletu 7" i 10":**
    *   Google wymaga wgrania zrzutów dla tabletów, jeśli aplikacja ma być promowana na te urządzenia (można użyć plansz wygenerowanych dla iPada).

### 2.2 Dane do weryfikacji aplikacji (App Access)
Jeśli aplikacja wymaga logowania, Google Play Console wymaga podania danych testowych w zakładce **Polityka i treść** -> **Dostęp do aplikacji**:
*   **Nazwa użytkownika:** `apple-test2@superwizor.ai` *(można stworzyć osobne konto google-test@superwizor.ai w Firebase, jeśli chcesz oddzielić ruch)*
*   **Hasło:** `SuperwizorApple2026!`
*   **Instrukcja (Parameters):** Dokładnie ta sama, co dla Apple (Krok 1.2).

### 2.3 Teksty marketingowe Google Play
*   **Nazwa aplikacji:** `SuperWizor AI` (maks. 30 znaków)
*   **Krótki opis:** `Poznawczy partner w gabinecie psychoterapeuty.` (maks. 80 znaków)
*   **Pełny opis:** *(Ten sam opis co w sekcji 1.3, maksymalnie 4000 znaków).*

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
