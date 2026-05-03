# 07_FAZA_3_AI_PIPELINE

Ten dokument opisuje szczegółowy plan Fazy 3: "Deployment i Uruchomienie Potoku AI (Cloud Functions)". Kod aplikacji (`ai-pipeline-svc`) został już napisany w Fazie 2, jednak teraz musimy powołać do życia środowisko uruchomieniowe w Google Cloud, by połączyć nagrania z chmury z modelami sztucznej inteligencji.

## 🎯 Cel Główy
Pełna automatyzacja i wdrożenie serwerlessowego potoku przetwarzania audio (Event-Driven Architecture). Kiedy plik audio wpadnie do bucketu, system ma bez ingerencji człowieka wykonać kolejno transkrypcję (Chirp 3) oraz wygenerować raport analityczny (Gemini 3.1 FLASH).

---

## 📋 Szczegółowy Plan Wdrożenia

### [x] KROK 1: Aktywacja Wymaganych API w Google Cloud
Zanim zdefiniujemy zasoby w Terraformie, upewnimy się, że wszystkie odpowiednie usługi na naszym projekcie (`superwizor-ai-25ecd`) są włączone.
- [x] `cloudfunctions.googleapis.com` (Cloud Functions)
- [x] `run.googleapis.com` (Cloud Run - wymagany dla Cloud Functions Gen2)
- [x] `cloudbuild.googleapis.com` (Cloud Build - wymagany do budowania obrazów z kodu Go)
- [x] `eventarc.googleapis.com` (Eventarc - do nasłuchiwania zdarzeń Pub/Sub)
- [x] `speech.googleapis.com` (Cloud Speech-to-Text V2 - dla modelu Chirp 3)
- [x] `aiplatform.googleapis.com` (Vertex AI API - dla modelu Gemini)

### [x] KROK 2: Moduł Terraform (`cloud-functions`)
W katalogu `superwizor-backend/infra/modules/cloud-functions` stworzymy od zera nowy moduł IaC. Będziemy korzystać z Cloud Functions Gen2 (pod spodem Cloud Run).
- [x] Zdefiniowanie bucketu `superwizor-ai-25ecd-functions-source` do przechowywania spakowanego kodu źródłowego (`.zip`).
- [x] Przygotowanie skryptu lub konfiguracji pakującej kod z folderów `cmd/stt-worker` oraz `cmd/llm-worker`.
- [x] Zdefiniowanie zasobu `google_cloudfunctions2_function` dla **`stt-worker`**.
- [x] Zdefiniowanie zasobu `google_cloudfunctions2_function` dla **`llm-worker`**.

### [x] KROK 3: Konfiguracja Eventów i Pub/Sub (Eventarc)
Zgodnie ze stworzoną wcześniej architekturą Event-Driven, musimy połączyć zdarzenia wyzwalające:
- [x] **Trigger dla `stt-worker`**: Podpięcie do topicu `audio.uploaded`.
  * *Mechanika:* Kiedy Cloud Storage wyśle powiadomienie, że nagranie się pojawiło, Pub/Sub obudzi `stt-worker`, który ściągnie audio, puści przez Chirp 3, i opublikuje sygnał do nowego topicu.
- [x] Zdefiniowanie w Terraform nowego topicu Pub/Sub: `transcript.completed`.
- [x] **Trigger dla `llm-worker`**: Podpięcie do topicu `transcript.completed`.
  * *Mechanika:* Kiedy `stt-worker` poinformuje, że transkrypcja w bazie jest gotowa, `llm-worker` czyta ją z PostgreSQL i puszcza do Gemini w Vertex AI.

### [x] KROK 4: Role IAM i Uprawnienia (Least Privilege)
Architektura w oparciu o *Least Privilege*. Terraform stworzy konta `stt-worker@...` oraz `llm-worker@...`:
- [x] `stt-worker` otrzyma role: `roles/storage.objectViewer` do plików audio, `roles/speech.client` do używania Chirp 3.
- [x] `llm-worker` otrzyma rolę `roles/aiplatform.user` do wywołań Gemini.
- [x] Obydwa konta otrzymają rolę `roles/cloudsql.client` do komunikacji z bazą.

### [x] KROK 5: Połączenie z PostgreSQL
Funkcje bezserwerowe operują w oddzielnych środowiskach sieciowych, dlatego:
- [x] Konfiguracja połączenia funkcji do Cloud SQL w Gen2 (Direct VPC Egress lub mechanizm konektorów, wstrzyknięcie poprawnych URI bazy danych).
- [x] Podpięcie zmiennych środowiskowych `DATABASE_URL`, `GCP_PROJECT_ID` itd. pod wdrożone instancje funkcji.

### [ ] KROK 6: Rzeczywisty E2E Cloud Test (Finał)
- [x] Wykonanie `terraform apply` z katalogu staging.
- [ ] Nagranie sesji przez aplikację Flutter, bez udziału lokalnego środowiska deweloperskiego (komputer może być wyłączony, aplikacja działa "na czysto").
- [ ] Obserwacja logów `stt-worker` oraz `llm-worker` w Cloud Logging.
- [ ] Weryfikacja w bazie danych:
  - Status sesji powinien zmienić się na `ANALYZING` i w końcu na `COMPLETED`.
  - Tabela `transcripts` powinna zawierać pełną treść podzieloną na prelegentów.
  - Tabela z analizą (lub kolumny) powinna zawierać odpowiedź wygenerowaną przez Gemini.

---

## 📌 Kryteria Sukcesu (Definition of Done)
1. Moduł `cloud-functions` jest poprawnie wdrożony i widoczny w stanie środowiska Terraform.
2. Zdarzenia z GCS przechodzą z sukcesem do Cloud Functions.
3. API Speech i Vertex AI nie rzucają błędów uwierzytelniania w logach.
4. Wyniki lądują w bazie PostgreSQL bez manualnej interwencji inżyniera.
