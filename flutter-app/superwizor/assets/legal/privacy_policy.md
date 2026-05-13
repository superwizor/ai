# Polityka Prywatności aplikacji Superwizor AI

*Data ostatniej aktualizacji: 21 lipca 2025 r.*

---

## W skrócie (TL;DR)

- Twoje dane i dane Twoich pacjentów są przechowywane **wyłącznie na serwerach w Unii Europejskiej** (region: `europe-central2`, Warszawa).
- Nagrania audio i transkrypcje są szyfrowane end-to-end. Nikt z zespołu Superwizor AI nie ma dostępu do treści sesji.
- **Nigdy** nie sprzedajemy Twoich danych ani danych Twoich pacjentów.
- Przysługuje Ci pełne prawo do usunięcia konta i wszystkich danych.

Kontakt: **kontakt@superwizor.ai**

---

## Część I — Dane Użytkowników Profesjonalnych

### 1. Administrator danych

Administratorem Twoich danych osobowych (jako terapeuty korzystającego z Aplikacji) jest:

**Euphire sp. z o.o.**
ul. Odrzańska 10a/48, 30-408 Kraków
KRS: 0000907254 · NIP: 6793219020
E-mail: kontakt@superwizor.ai

### 2. Jakie dane zbieramy i po co?

| Cel przetwarzania | Kategorie danych | Podstawa prawna |
|---|---|---|
| Założenie i obsługa konta | E-mail, imię, nazwisko, zdjęcie profilowe | Wykonanie umowy (art. 6 ust. 1 lit. b RODO) |
| Świadczenie usług AI | Nagrania audio, transkrypcje (per sesja) | Wykonanie umowy |
| Rozliczenia i faktury | Dane płatnicze, dane firmy | Obowiązek prawny (art. 6 ust. 1 lit. c RODO) |
| Bezpieczeństwo i zapobieganie nadużyciom | Logi dostępu, adres IP | Uzasadniony interes (art. 6 ust. 1 lit. f RODO) |
| Marketing (za zgodą) | E-mail | Zgoda (art. 6 ust. 1 lit. a RODO) |

### 3. Jak długo przechowujemy dane?

- **Dane konta:** przez czas trwania umowy + 30 dni po jej rozwiązaniu (na potrzeby exportu)
- **Nagrania i transkrypcje:** do momentu usunięcia przez Użytkownika lub rozwiązania umowy
- **Dane płatnicze i faktury:** przez 5 lat zgodnie z przepisami podatkowymi
- **Logi bezpieczeństwa:** 12 miesięcy

### 4. Gdzie przechowujemy dane?

Wszystkie dane przechowywane są **wyłącznie w Unii Europejskiej**, na infrastrukturze Google Cloud Platform w regionie `europe-central2` (Warszawa, Polska).

Nie przekazujemy danych do państw trzecich, z wyjątkiem usług AI (Vertex AI / Gemini), gdzie dane są przetwarzane w regionie `europe-west4` (Holandia) na podstawie standardowych klauzul umownych (SCC).

### 5. Bezpieczeństwo danych

Stosujemy następujące środki techniczne i organizacyjne:

- **Szyfrowanie w spoczynku:** AES-256 (Google Cloud KMS)
- **Szyfrowanie w tranzycie:** TLS 1.3
- **Szyfrowanie PHI (danych szczególnie wrażliwych):** envelope encryption z dedykowanymi kluczami per-terapeuta (Cloud KMS)
- **Kontrola dostępu:** Zero Trust, dedykowane konta serwisowe z minimalnym zakresem uprawnień
- **Audyt:** logi wszystkich operacji na danych wrażliwych

### 6. Twoje prawa

Przysługuje Ci prawo do:
- **Dostępu** do swoich danych
- **Sprostowania** nieprawidłowych danych
- **Usunięcia** danych (prawo do bycia zapomnianym)
- **Przenoszenia** danych w formacie JSON/PDF
- **Sprzeciwu** wobec przetwarzania na podstawie uzasadnionego interesu
- **Wniesienia skargi** do Prezesa UODO (uodo.gov.pl)

Aby skorzystać z praw, napisz na: **kontakt@superwizor.ai**

### 7. Sub-procesorzy (podmioty przetwarzające dane w naszym imieniu)

| Sub-procesor | Cel | Region |
|---|---|---|
| Google Cloud Platform | Hosting infrastruktury | EU (europe-central2) |
| Firebase Authentication | Uwierzytelnianie użytkowników | EU |
| Firebase Storage | Tymczasowe przechowywanie nagrań | EU |
| Cloud Speech-to-Text (Chirp 3) | Transkrypcja audio | EU |
| Vertex AI / Gemini | Analiza kliniczna AI | EU (europe-west4) |
| Stripe | Obsługa płatności | EU |

---

## Część II — Informacje dla Pacjentów

*Ta sekcja skierowana jest do pacjentów, których dane są przetwarzane przez Twoich terapeutów używających Superwizor AI.*

### Kim jesteśmy w kontekście Twoich danych?

**Twój terapeuta** (Użytkownik Profesjonalny Superwizor AI) jest **Administratorem** Twoich danych osobowych — to on/ona decyduje o celu i zakresie ich przetwarzania.

**Euphire sp. z o.o.** jest **Podmiotem Przetwarzającym** — udostępniamy jedynie narzędzie techniczne i przetwarzamy Twoje dane wyłącznie na polecenie Twojego terapeuty, zgodnie z DPA.

### Jakie dane mogą być przetwarzane?

W zależności od tego, co nagrywane jest podczas sesji:
- Głos (nagranie audio sesji terapeutycznej)
- Transkrypcja wypowiedzi z etykietami mówców (bez imion — etykiety neutralne)
- Dane dotyczące zdrowia psychicznego zawarte w treści rozmowy (dane szczególnej kategorii, art. 9 RODO)

### Podstawa prawna i zgoda

Twój terapeuta jest zobowiązany do uzyskania Twojej wyraźnej zgody na nagrywanie i przetwarzanie danych przy użyciu Superwizor AI, przed każdą nagraną sesją.

### Twoje prawa jako pacjenta

Masz prawo zwrócić się bezpośrednio do swojego terapeuty (Administratora) o:
- Dostęp do danych z Twoich sesji
- Usunięcie danych (trwałe usunięcie kartoteki)
- Ograniczenie przetwarzania

Możesz również skontaktować się z nami bezpośrednio: **kontakt@superwizor.ai**

---

## Część III — Pliki cookie i analityka

Aplikacja mobilna nie używa plików cookie. Może zbierać anonimowe dane analityczne (Firebase Analytics) w celu poprawy jakości działania aplikacji. Dane te nie zawierają żadnych danych osobowych ani treści sesji.

---

*Polityka Prywatności wchodzi w życie z dniem 21 lipca 2025 r.*
