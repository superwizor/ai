# 07_FAZA_3_AI_PIPELINE

Ten dokument opisuje szczegółowy, techniczny plan dla **Fazy 2.5 → 3**: "Deployment i Uruchomienie Potoku AI (Cloud Functions) oraz poprawki stabilności i bezpieczeństwa".

## 🎯 Cel Główny
Pełna automatyzacja i wdrożenie serwerlessowego potoku przetwarzania audio (Event-Driven Architecture) z zachowaniem Zero Trust i enkrypcji envelope (Cloud KMS). Kiedy plik audio zostanie przesłany z aplikacji Flutter do Cloud Storage, system automatycznie wykonuje transkrypcję (Chirp 3) i raport (Gemini 3.1 FLASH).

---

## 🎯 Następne Kroki (Faza 2.5 → 3) - Szczegółowy Plan Wdrożenia

### Priorytet 1: Pipeline Transkrypcji
**Cel:** Automatyczne pobranie wrzuconego pliku z GCS, transkrypcja za pomocą modelu Chirp 3 (z diarization) i zapisanie wyników do bazy.

1. **Utworzyć Pub/Sub topic `audio.uploaded` w Terraform**
   - **Gdzie:** `infra/modules/audio-storage/main.tf` lub nowy moduł eventów.
   - **Szczegóły:** Skonfigurować resource `google_pubsub_topic` o nazwie `audio.uploaded`.
   - **Integracja GCS:** Użyć `google_storage_notification`, aby bucket `superwizor-audio-uploads` wysyłał eventy `OBJECT_FINALIZE` prosto na ten topic.
2. **Deploy `stt-worker` jako Cloud Function (Gen2, event-driven)**
   - **Gdzie:** Moduł Terraform `infra/modules/cloud-functions` lub w staging `main.tf`.
   - **Szczegóły:** Zdefiniować `google_cloudfunctions2_function`. Ustawić region na `europe-west4` (zgodnie z ADR dla dostępności Chirp 3) lub `europe-central2` z remote call. Przekazać zmienne środowiskowe: `DATABASE_URL`, klucze KMS. 
3. **Skonfigurować trigger: `audio.uploaded` → `stt-worker`**
   - **Szczegóły:** Ustawić `event_trigger` na Pub/Sub topic `audio.uploaded` poprzez Eventarc. Dzięki temu każdy wgrany przez pacjenta/terapeutę plik audio automatycznie odpali kod workera.
4. **Przetestować E2E: nagranie → upload → transkrypcja**
   - **Oczekiwany rezultat:** Nagranie we Flutterze ➜ Upload na Signed URL ➜ GCS emituje event ➜ `stt-worker` dekoduje audio i wywołuje Google Speech-to-Text V2 (Chirp 3).
   - **Baza Danych:** Sprawdzenie tabel `transcript_segments` oraz blob w `transcripts.transcript_ciphertext`.

### Priorytet 2: Pipeline Raportów AI
**Cel:** Wygenerowanie 7-sekcyjnego, uporządkowanego raportu przez LLM (Gemini 3.1 FLASH) na podstawie przetworzonego transkryptu.

1. **Utworzyć Pub/Sub topic `transcript.completed`**
   - **Szczegóły:** Dodanie definicji `google_pubsub_topic` dla `transcript.completed` w Terraform. Temat ten jest wyzwalany przez samą funkcję `stt-worker` po skutecznym zapisie transkryptu do bazy.
2. **Deploy `report-worker` (LLM — 7-sekcyjny raport)**
   - *(Uwaga: W architekturze z Fazy 2 worker był nazywany `llm-worker`)*
   - **Szczegóły:** Definicja `google_cloudfunctions2_function` dla `report-worker`. Region `europe-west4` (wymagania Vertex AI). Wstrzyknięcie struktury raportu (JSON Schema dla structured output z Gemini) zawierającej 7 wymaganych sekcji (w oparciu o EUPHIRE).
3. **Skonfigurować trigger: `transcript.completed` → `report-worker`**
   - **Szczegóły:** W konfiguracji Terraform ustawić `event_trigger` na nowo utworzony topic. Worker czyta `transcript_id`, wyciąga pełny zdekodowany tekst i pyta model Vertex AI.
4. **Przetestować: transkrypcja → raport AI**
   - **Oczekiwany rezultat:** Po zakończeniu STT zostaje wygenerowany event. `report-worker` pobiera transkrypt, odpytuje Gemini i zapisuje szyfrowany wynik jako JSONB / blob do tabeli `reports.report_ciphertext`.

### Priorytet 3: Naprawić `GetSessionDetails`
**Cel:** Serwis kliniczny (`clinical-svc`) musi poprawnie agregować dane o sesji i zwracać je do aplikacji mobilnej.

1. **Upewnić się, że `clinical-svc` czyta z tej samej tabeli `sessions` co `ingestion-svc`**
   - **Szczegóły:** `ingestion-svc` tworzy rekord w tabeli `sessions` po wgraniu pliku. Kod źródłowy w repozytorium (katalogi `services/clinical-svc/` i `services/ingestion-svc/`) musi polegać na spójnym użyciu tych samych queries SQL (`sqlc`).
2. **Implementacja pełnego query z JOIN na `transcripts` + `reports`**
   - **Szczegóły:** Rozbudować zapytanie `.sql` dla `GetSessionDetails` (w `clinical-svc/internal/adapters/db/query.sql`), aby pobierało dane w relacji:
     ```sql
     SELECT s.*, t.transcript_ciphertext, r.report_ciphertext 
     FROM sessions s
     LEFT JOIN transcripts t ON t.session_id = s.id
     LEFT JOIN reports r ON r.session_id = s.id
     WHERE s.id = $1;
     ```
   - **Deszyfrowanie:** Backend musi w locie zdeszyfrować `transcript_ciphertext` oraz `report_ciphertext` z KMS, zanim przekaże dane po gRPC do Fluttera.

### Priorytet 4: Security Hardening
**Cel:** Spełnienie wymogów medycznych Zero Trust - każdy wrażliwy element przechodzi przez mocne szyfrowanie envelope i posiada minimalne uprawnienia.

1. **Cloud KMS envelope encryption (zamienić placeholder DEK)**
   - **Gdzie:** Kod w folderze `pkg/cryptobox` oraz użycie w workerach i mikroserwisach.
   - **Szczegóły:** Aktualnie klucze mogły mieć charakter placeholderów dla fazy deweloperskiej. Należy wywołać bezpośrednio Google Cloud KMS (używając klucza `database` lub `app-data` wygenerowanego w Fazie 0) w celu stworzenia (Wrap) i deszyfrowania (Unwrap) klucza Data Encryption Key (DEK). 
   - Wymienić starą logikę w `stt-worker` oraz `report-worker`, by zawsze używały integracji z chmurowym KMS dla kolumn `..._ciphertext` oraz `..._encrypted_dek`.
2. **Audit IAM ról — principle of least privilege**
   - **Szczegóły:** Weryfikacja w Terraform kont serwisowych i ograniczenie praw do niezbędnego minimum:
     - `stt-worker`: potrzebuje `roles/storage.objectViewer`, `roles/speech.client`, `roles/pubsub.publisher`, `roles/cloudkms.cryptoKeyEncrypterDecrypter`, `roles/cloudsql.client`.
     - `report-worker`: potrzebuje `roles/aiplatform.user`, `roles/cloudkms.cryptoKeyEncrypterDecrypter`, `roles/cloudsql.client`.
     - `clinical-svc`: potrzebuje `roles/cloudkms.cryptoKeyEncrypterDecrypter` (by rozszyfrować raport), `roles/cloudsql.client`.
     - Upewnić się, że żadna z funkcji nie posiada roli typu `roles/editor` ani dostępu "admin".
