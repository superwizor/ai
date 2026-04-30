# Dostęp do Projektu: Superwizor AI

Wszystkie kluczowe konta oraz infrastruktura opierają się na dedykowanym adresie e-mail:
**E-mail głównego konta (Admin):** `kontakt@superwizor.ai`
**Domena główna:** `superwizor.ai` (Cloudflare)

---

## 1. Google Workspace (Organizacja)
- **Organizacja:** O godz. 14:58 utworzono oficjalną organizację `superwizor.ai` w Google Workspace.
- **Konto Administratora:** Użytkownikowi `kontakt@superwizor.ai` przydzielono rolę administratora organizacji.
- **Zastosowanie:** Tego adresu e-mail używamy jako głównego konta zarządzającego infrastrukturą projektu, kodem źródłowym i płatnościami.

---

## 2. Kod Źródłowy (GitHub)
- **Repozytorium:** [superwizor/ai](https://github.com/superwizor/ai)
- **Gałąź główna (produkcyjna):** `main`
- **Jak nadać dostęp dla `kontakt@superwizor.ai`:**
  1. Zaloguj się na konto i wejdź na [stronę Collaborators](https://github.com/superwizor/ai/settings/access).
  2. Kliknij zielony przycisk **Add people**.
  3. Wpisz e-mail `kontakt@superwizor.ai` i wyślij zaproszenie z uprawnieniami (najlepiej najwyższymi).

---

## 3. Baza Danych, Backend i Hosting (Firebase / Google Cloud)
- **Konsola Google Cloud:** [Przejdź do GCP](https://console.cloud.google.com/)
- **Konsola Firebase:** [Przejdź do panelu projektu](https://console.firebase.google.com/)
- **Nazwa Projektu:** Superwizor AI
- **Project ID (GCP & Firebase):** `superwizor-ai-25ecd`
- **Region infrastruktury (Żelazna Lokalizacja):** `europe-central2` (Warszawa)
- **Konto billingowe:** Podpięte do `kontakt@superwizor.ai` (Direct)
- **Podpięte platformy (zarejestrowane aplikacje):**
  - Android (`1:344724821207:android:6cf6ba9f8fe803eaa98c92`)
  - iOS / macOS (`1:344724821207:ios:74fa7d1d312fcec9a98c92`)
  - Web / Windows (`1:344724821207:web:3e2ca4d5fcfdc640a98c92`)
- **Status:** **ZAKOŃCZONO ✅**. Środowisko podłączone do aplikacji klienckiej (Flutter). Czeka na wdrożenie infrastruktury bazy danych.

---

## 4. Płatności i Subskrypcje (Stripe)
- **Panel Stripe:** [Przejdź do Dashboardu (Developers -> API keys)](https://dashboard.stripe.com/test/apikeys)
- **Logowanie:** Główne konto EUPHIRE, ale działa na dedykowanym i wydzielonym Sub-koncie o nazwie "Superwizor AI".
- **Account ID:** `acct_1TREGgE5jzWcAIge`
- **Klucze API (Test mode):**
  - **Publishable key** (do frontendu): *...do uzupełnienia...*
  - **Secret key** (do backendu): *...do uzupełnienia...*
- **Status:** **ZWALIDOWANY ✅**. Terminal i agent AI są poprawnie podłączone przez Stripe CLI i zintegrowane oficjalnymi "skillami" zespołu Stripe.
