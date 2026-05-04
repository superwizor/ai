# 07_FAZA_3_AI_PIPELINE

Ten dokument opisuje szczegółowy, techniczny plan dla **Fazy 2.5 → 3**: "Deployment i Uruchomienie Potoku AI (Cloud Functions) oraz poprawki stabilności i bezpieczeństwa".

> **🚨 THE ENFORCER CHECKLIST (z `B_04_core_rules.md`)**
> Podczas kodowania tej fazy bezwzględnie egzekwuj:
> 1. **Zero Data Loss:** Odporność uploadu audio i transkryptu na usypianie urządzeń i awarie sieci.
> 2. **Krematorium Danych (OLM):** Pliki `.m4a` muszą zniknąć po 48h.
> 3. **Zero PII (Ślepota AI):** Do workerów trafiają wyłącznie aliasy (np. "Osoba 1").
> 4. **Test-Driven Development (TDD):** Kodujemy najpierw testy. Izolacja z użyciem `mocktail`/`gomock`.
> 5. **Crashlytics & Telemetria:** Niezawodne owijanie wywołań w try-catch (Flutter) i dodawanie niemych zdarzeń Firebase Analytics B2B.

---

## 🎯 Następne Kroki (Faza 2.5 → 3) - Szczegółowy Plan Wdrożenia

### Priorytet 1: Pipeline Transkrypcji
**Cel:** Automatyczne i bezstanowe przetwarzanie plików audio na transkrypcję Chirp 3 po zdarzeniu z GCS.

- [x] **KROK 1.1:** W Terraform `infra/modules/pubsub/main.tf` utwórz Pub/Sub topic `audio.uploaded`.
- [x] **KROK 1.2:** Dodaj notyfikację `google_storage_notification` z `superwizor-audio-uploads` na topic `audio.uploaded` (względem reguły Krematorium Danych).
- [x] **KROK 1.3:** W `infra/modules/cloud-functions/main.tf` dodaj `stt-worker` Gen2.
- [x] **KROK 1.4:** Podepnij Eventarc trigger: `audio.uploaded` → `stt-worker`.
- [ ] **Kryteria wykonania (DoD):** Po wysłaniu pliku `m4a` na Signed URL, logi `stt-worker` pokazują poprawne uruchomienie Chirp 3, brak PII oraz poprawne zapisanie wygenerowanego transkryptu do bazy.
- [ ] **Wymagane testy:** TDD dla parsera Chirp 3 (mock klienta `speech.Client`), test jednostkowy sprawdzający prawidłowe tworzenie eventu `transcript.completed`.

### Priorytet 2: Pipeline Raportów AI
**Cel:** Wygenerowanie 7-sekcyjnego raportu (Gemini 3.1 FLASH) z zachowaniem zasady Ślepoty (Zero PII).

- [x] **KROK 2.1:** W Terraform utwórz temat Pub/Sub `transcript.completed`.
- [x] **KROK 2.2:** Zdefiniuj zasób `report-worker` (w kodzie jako `llm-worker`) w Cloud Functions Gen2.
- [x] **KROK 2.3:** Podepnij Eventarc trigger: `transcript.completed` → `report-worker`. Zadbaj o bezpieczne przesyłanie kontekstu bez imion z użyciem zaszyfrowanego blob'u (ADR-IMPL-006).
- [x] **Kryteria wykonania (DoD):** Worker dekoduje wynik transkryptu z użyciem KMS, wysyła czysty prompt do Vertex AI (zgodnie ze strukturą `report_schema.json`) i zapisuje `report_ciphertext`.
- [x] **Wymagane testy:** TDD dla generowania promptu i parsowania JSON Schema. Stub Vertex AI klienta, weryfikujący czy model na wejściu na pewno nie dostaje identyfikatorów pacjenta.

### Priorytet 3: Naprawić `GetSessionDetails` (ZROBIONE)
**Cel:** Serwis kliniczny (`clinical-svc`) musi poprawnie agregować dane o sesji i zwracać je do aplikacji mobilnej.

1. **Upewnić się, że `clinical-svc` czyta z tej samej tabeli `sessions` co `ingestion-svc`**
   - **Szczegóły:** `ingestion-svc` i `clinical-svc` łączą się z tą samą bazą dzięki wspólnemu URL bazy.
2. **Implementacja query agregującego `transcripts` + `reports`**
   - **Szczegóły:** Zapytanie jest zrealizowane poprzez optymalne pojedyncze pobrania bez nadmiarowego Cartesian Product. 
   - **Deszyfrowanie:** Zaimplementowane na poziomie Cloud Functions/workera.

### Priorytet 4: Security Hardening (Cloud KMS)
**Cel:** Odrzucenie deweloperskich placeholderów na rzecz prawdziwego uwierzytelnienia.

- [ ] **KROK 4.1:** Zamień `ENCRYPT_PLACEHOLDER:` oraz `DEK_PLACEHOLDER` w `stt-worker`, `report-worker` oraz `clinical-svc` na realne wywołania KMS do klucza `app-data-key` z `infra/modules/kms/main.tf`.
- [ ] **KROK 4.2:** Aktualizacja ról IAM zgodnie ze ścisłym Principle of Least Privilege:
  - `stt-worker`: usunąć nadmiarowe role, przypisać tylko `cloudkms.cryptoKeyEncrypterDecrypter`, `storage.objectViewer`, `pubsub.publisher`, `speech.client`.
  - `report-worker`: `aiplatform.user`, `cloudkms.cryptoKeyEncrypterDecrypter`.
- [ ] **Kryteria wykonania (DoD):** Usunięcie wszystkich referencji do `ENCRYPT_PLACEHOLDER` z bazy kodu. Aplikacja nadal płynnie zapisuje i czyta sesje, a logi Terraform pokazują dokładne okrojenie ról.
- [ ] **Wymagane testy:** Test e2e kryptografii - z użyciem lokalnego symulatora KMS (bądź mocka Cryptobox).
