---
type: Legacy Architecture
title: "Dostęp do Projektu: Superwizor AI"
description: "Wszystkie kluczowe konta oraz infrastruktura opierają się na dedykowanym adresie e-mail: E-mail głównego konta (Admin): kontakt@superwizor.ai Domena główna: ..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/stare%20arhcitektury%20%28Maciek%29/B_00_project_access_links.md
tags: [stare-arhcitektury--maciek-]
timestamp: 2026-05-30T14:32:36+02:00
---

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
- **Konsola Firebase:** [Przejdź do panelu projektu](https://console.firebase.google.com/)
- **Nazwa Projektu:** Superwizor AI
- **Project ID:** `superwizor-ai-25ecd`
- **Podpięte platformy (zarejestrowane aplikacje):**
  - Android (`1:344724821207:android:6cf6ba9f8fe803eaa98c92`)
  - iOS / macOS (`1:344724821207:ios:74fa7d1d312fcec9a98c92`)
  - Web / Windows (`1:344724821207:web:3e2ca4d5fcfdc640a98c92`)
- **Status:** **ZAKOŃCZONO ✅**. Środowisko Firebase połączone z aplikacją.

---

## 4. Płatności i Subskrypcje (Stripe)
- **Panel Stripe:** [Przejdź do Dashboardu (Developers -> API keys)](https://dashboard.stripe.com/test/apikeys)
- **Logowanie:** Główne konto EUPHIRE, ale działa na dedykowanym i wydzielonym Sub-koncie o nazwie "Superwizor AI".
- **Account ID:** `acct_1TREGgE5jzWcAIge`
- **Klucze API (Test mode):**
  - **Publishable key** (do frontendu): *...do uzupełnienia...*
  - **Secret key** (do backendu): *...do uzupełnienia...*
- **Status:** **ZWALIDOWANY ✅**. Terminal i agent AI są poprawnie podłączone przez Stripe CLI i zintegrowane oficjalnymi "skillami" zespołu Stripe.

---

## 5. Infrastruktura Backendowa (Google Cloud Platform - GCP)
Infrastruktura jest zautomatyzowana za pomocą Terraform (`superwizor-backend/infra`) i znajduje się w projekcie **`superwizor-ai-25ecd`** w regionie `europe-central2` (Warszawa).

### A. Cloud SQL (PostgreSQL 16)
Baza danych dla backendu jest zarządzana w Cloud SQL. Hasła i sekrety przechowujemy bezpiecznie w Secret Manager.
- **Instance ID:** `superwizor-db-4d61ad78`
- **Database Name:** `superwizor`
- **Database User:** `superwizor_app`
- **Hasło DB:** Zarządzane przez Google Secret Manager (`superwizor-db-password`).
- **Autoryzacja (Sieć):** Sieć lokalna programisty (`91.226.22.63/32`) ma autoryzowany bezpośredni dostęp do bazy po publicznym IP.

#### Konfiguracja MCP (Model Context Protocol) dla Cloud SQL:
Używając serwera MCP Cloud SQL na lokalnej maszynie, wpisz następujące wartości:
- **Cloud SQL Project ID:** `superwizor-ai-25ecd`
- **Cloud SQL Region:** `europe-central2`
- **Cloud SQL Instance ID:** `superwizor-db-4d61ad78`
- **Cloud SQL Database Name:** `superwizor`
- **Cloud SQL Database User:** `superwizor_app`
- **Cloud SQL IP Type:** `Public` (dzięki whiteliscie IP w konfiguracji Terraform)

### B. Event-Driven AI Pipeline (Pub/Sub + Cloud Functions)
Przetwarzanie audio z sesji i generowanie notatek jest całkowicie oparte na zdarzeniach (Event-Driven) i nie blokuje aplikacji. W jego skład wchodzą dwa główne procesy (Cloud Functions):
1. **STT Worker (Speech-to-Text):**
   - **Wyzwalacz:** Wysyłany event na szynę Pub/Sub (`audio_uploaded_topic`), gdy nowe audio ląduje w GCS (bucket `audio_uploads`).
   - **Cel:** Przetworzenie audio na tekst. Zapisanie wyników i wysłanie eventu na kolejny temat.
2. **LLM Worker (Vertex AI):**
   - **Wyzwalacz:** Event na Pub/Sub (`transcript_completed_topic`) z informacją o zakończonej transkrypcji.
   - **Cel:** Przekazanie transkrypcji do Vertex AI (np. modele Gemini), w celu wygenerowania ustrukturyzowanej notatki dla psychoterapeuty z odbytej sesji.

### C. Bezpieczeństwo i IAM
- **KMS (Key Management Service):** Wykorzystujemy szyfrowanie envelope encryption do zabezpieczenia danych w Cloud SQL.
- **Workload Identity Federation (WIF):** Zapewnia bezhasłowy dostęp i deployment z GitHub Actions do środowiska Google Cloud (`baciok91/superwizor-backend`).

### D. Service Accounts & Least Privilege (Architektura IAM)
Wdrożyliśmy rygorystyczne zasady "Least Privilege" dla każdego mikroserwisu. Zamiast domyślnych kont Compute Engine, każdy serwis i worker w Cloud Run / Cloud Functions działa na własnym koncie serwisowym (Service Account) z precyzyjnie dobranymi uprawnieniami (wykonane i zarządzane z poziomu Terraform):

1. **`ingestion-svc`** (`ingestion-svc@superwizor-ai-25ecd.iam.gserviceaccount.com`):
   - **Publikacja zdarzeń:** `roles/pubsub.publisher` (dla topicu `audio.uploaded`).
   - **Szyfrowanie KMS:** `roles/iam.serviceAccountTokenCreator`, `roles/cloudkms.cryptoKeyEncrypterDecrypter`.
   - **Baza danych:** `roles/cloudsql.client` oraz `roles/secretmanager.secretAccessor` (pobieranie hasła z Secret Managera).
   - **Cloud Storage:** `roles/storage.objectAdmin` (dostęp zapisu/usuwania wyłącznie dla bucketu `audio_uploads`).

2. **`stt-worker`** (`stt-worker@superwizor-ai-25ecd.iam.gserviceaccount.com`):
   - **Publikacja zdarzeń:** `roles/pubsub.publisher` (dla topicu `transcript.completed`).
   - **AI / Model:** `roles/speech.client` (wywoływanie modeli Chirp 3).
   - **Storage & KMS:** `roles/cloudkms.cryptoKeyEncrypterDecrypter`, `roles/storage.objectViewer`.

3. **`llm-worker`** (`llm-worker@superwizor-ai-25ecd.iam.gserviceaccount.com`):
   - **Publikacja zdarzeń:** `roles/pubsub.publisher` (dla topicu `report.generated`).
   - **AI / Model:** `roles/aiplatform.user` (wywoływanie Vertex AI / Gemini).
   - **Szyfrowanie KMS:** `roles/cloudkms.cryptoKeyEncrypterDecrypter`.
   - **Baza danych:** Wymaga analogicznych uprawnień jak `ingestion-svc` do zapisu wygenerowanych struktur JSON w głównej bazie.
