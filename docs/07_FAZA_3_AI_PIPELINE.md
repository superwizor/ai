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
- [x] **Kryteria wykonania (DoD):** Po wysłaniu pliku `m4a` na Signed URL, logi `stt-worker` pokazują poprawne uruchomienie Chirp 3, brak PII oraz poprawne zapisanie wygenerowanego transkryptu do bazy.
- [x] **Wymagane testy:** TDD dla parsera Chirp 3 (mock klienta `speech.Client`), test jednostkowy sprawdzający prawidłowe tworzenie eventu `transcript.completed`.

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

- [x] **KROK 4.1:** Zamień `ENCRYPT_PLACEHOLDER:` oraz `DEK_PLACEHOLDER` w `stt-worker`, `report-worker` oraz `clinical-svc` na realne wywołania KMS do klucza `app-data-key` z `infra/modules/kms/main.tf`.
- [x] **KROK 4.2:** Aktualizacja ról IAM zgodnie ze ścisłym Principle of Least Privilege:
  - `stt-worker`: usunąć nadmiarowe role, przypisać tylko `cloudkms.cryptoKeyEncrypterDecrypter`, `storage.objectViewer`, `pubsub.publisher`, `speech.client`.
  - `report-worker`: `aiplatform.user`, `cloudkms.cryptoKeyEncrypterDecrypter`.
- [x] **Kryteria wykonania (DoD):** Usunięcie wszystkich referencji do `ENCRYPT_PLACEHOLDER` z bazy kodu. Aplikacja nadal płynnie zapisuje i czyta sesje, a logi Terraform pokazują dokładne okrojenie ról.
- [x] **Wymagane testy:** Test e2e kryptografii - z użyciem lokalnego symulatora KMS (bądź mocka Cryptobox).

### Priorytet 5: Hardening natywnej diaryzacji Chirp 3 (post-launch, `feat/llm-optimisation`)

**Cel:** Odzyskanie chunków, którym Chirp 3 nie nadał `speaker_label`, tak żeby UI pokazywał wszystkich mówców widocznych w transkrypcie — a nie tylko tych, których Chirp etykietował konsekwentnie.

**Tło problemu** (sesja `26ecf316`, 2026-05-15): Chirp 3 z `SpeakerDiarizationConfig` *nie* etykietuje każdego słowa. W praktyce: dominujący mówca (terapeuta, dłuższe wypowiedzi) dostaje stabilne `speaker_label="1"`, ale słowa drugiego mówcy oraz krótkie wtrącenia często wracają z `speaker_label=""`. Nasz chunker traktuje `""` jako odrębny "speaker" od `"1"`, więc nieoznaczone runy stają się osierocone chunki `tag=0`, a downstream LLM nie ma do czego ich dołączyć. Efekt: `sessions.speaker_label_mapping = {"1": "Person 1"}` zamiast `{"1": ..., "2": ...}`, UI wyświetla jedną osobę.

- [x] **KROK 5.1:** `stt-worker.fillSpeakerLabels(words, maxGapMS)` — pre-chunker pass propagujący najbliższą niepustą `SpeakerLabel` w obie strony, ograniczony progiem pauzy z `chunker.DefaultConfig().PauseThresholdMS` (600ms). Nigdy nie przepuszcza etykiety przez pauzę — pauza jest jedynym sygnałem zmiany mówcy.
- [x] **KROK 5.2:** `llm-worker.markdownResultToPayload` — fallback dla trybu native: jeśli dokładnie **jedna** `SpeakerGroup` ma puste `ChunkIndices` i istnieją osierocone chunki `SpeakerTag=0`, przypisz wszystkie sieroty do tej pustej grupy. Wiele pustych grup → log warning, pominięcie (nie zgadujemy).
- [x] **KROK 5.3:** Testy jednostkowe `TestFillSpeakerLabels` — 7 przypadków: forward fill, stop na pauzie, backward fill, no-op gdy nic do etykietowania, niezmienialność istniejących etykiet, pusty input, oraz wierne odtworzenie kształtu produkcyjnej sesji `26ecf316`.
- [x] **Kryteria wykonania (DoD):** Po wgraniu sesji EN z dwoma mówcami: `sessions.speaker_label_mapping` zawiera oba taggi (`{"1": "Person 1", "2": "Person 2"}`), `transcript_segments` nie ma już wierszy `tag=0, label=""` (lub jest ich znikomo mało — krótkie filler-tokeny na granicach pauz), UI poprawnie wyświetla obie osoby.
- [x] **Wymagane testy:** Probe na staging — odtworzenie kształtu sesji `26ecf316` (terapeuta etykietowany, pacjent bez etykiet) i weryfikacja, że oba layery razem przywracają drugiego mówcę.

> **Cofalność:** Layer 1 mutuje listę słów in-place przed chunkowaniem — wpływa na każdą sesję z `useNativeDiarization=true`. Wyłączenie polega na cofnięciu commitu lub flippnięciu języka w `transcriptfmt.Chirp3DiarizationLanguages` na `false`. Layer 2 jest defensywny i nie szkodzi przy poprawnych wynikach Chirpa (warunek `emptyCount == 1` chroni dobre sesje).

> **Dlaczego nie tylko Layer 2:** Bez Layer 1 LLM otrzymuje Format B transkrypt, który mapuje wszystkie nieoznaczone słowa na `## Speaker 1` (`FormatSpeakerTurns` reguła "tag==0 → 1"), tracąc strukturę turn-taking widoczną w sygnale audio. Klastrowanie LLM stoi się trudniejsze, jakość ról spada. Layer 1 zachowuje kolejność i grupowanie w transkrypcie, Layer 2 ratuje pojedyncze osierocone runy, których Layer 1 nie objął (np. krótka odpowiedź pacjenta po pauzie, której Chirp w ogóle nie oetykietował).

> Szczegóły implementacji + ADR-IMPL-007a → `docs/agents/05_ai-pipeline-svc.md` sekcja "Native-diarization sparse-label recovery (2026-05-15)".

### Priorytet 6: Personalizacja raportów per terapeuta + system ocen (`feat/report-customization`, 2026-05-18)

**Cel:** Pozwolić terapeutom dostroić styl raportów (długość, ton, gęstość cytatów itp.) w prostym polskim — nie technicznie — przy zachowaniu klinicznego baseline'u promptu modalności. Plus lekki UX oceniania 👍/👎 z chipami szczegółów, który zamyka pętlę feedback → konfiguracja przez aktywny suggestion engine.

**Tło projektowe + decyzje:** `docs/10_REPORT_CUSTOMIZATION.md` (350+ linii, 7 wymiarów + free text, suggestion engine w v1, dziennik decyzji w §13).

#### Serwer-side (zrobione w db57fdb)

- [x] **KROK 6.1:** Migracja `000015_report_customization.up.sql`:
  - `ALTER users ADD COLUMN report_preferences JSONB DEFAULT '{}'`
  - `CREATE TABLE report_ratings` z `UNIQUE (report_id, therapist_id)`, FK CASCADE udokumentowane per ADR-DM-010
  - `CREATE TABLE preference_suggestions_log` (telemetria silnika sugestii)
- [x] **KROK 6.2:** `identity-svc.GetReportPreferences` / `UpdateReportPreferences` — RPC + closed enum allow-lists + cap 500 znaków na `free_text` + regex-odrzucenie wzorców prompt-injection (rejektuje, nie strippuje cicho — fail loud). Handler w `internal/adapters/grpc/preferences.go`.
- [x] **KROK 6.3:** `clinical-svc.RateReport` / `GetReportRating` / `GetActiveSuggestion` / `LogPreferenceSuggestion` — RPC + chip allow-list + sanityzacja notatek + silnik sugestii (≥3 negatywne oceny tej samej kategorii w 5 ostatnich raportach, 14-dniowy cooldown na dismissed). Handler w `internal/adapters/grpc/ratings.go`.
- [x] **KROK 6.4:** Nowy pakiet `ai-pipeline-svc/internal/reportprefs/` — sole consumer JSONB blob'u. `RenderFragment` produkuje polski fragment promptu PODRZĘDNY baseline'owi modalności ("NIE sprzeczne z powyższymi zasadami klinicznymi"). Zwraca "" dla defaultów / nieznanych enum-ów — zachowuje byte-identical prompty dla użytkowników bez konfiguracji.
- [x] **KROK 6.5:** `llm-worker` — `SessionContext` rozszerzony o `TherapistID + ReportPreferences`. `loadSessionContext` JOIN-uje przez `patient_files → users.report_preferences`. `generateReport` przyjmuje prefs, wstrzykuje fragment między prompt modalności a ZASADY ZWIĘZŁOŚCI, aplikuje cap na `MaxOutputTokens`.

> **Architektura cross-service:** identity-svc pozostaje na dnie drzewa zależności (`docs/agents/01_identity-svc.md`). Silnik sugestii żyje w clinical-svc (właściciel `report_ratings`). Flutter robi dwa równoległe wywołania na wejściu do ustawień: `identity.GetReportPreferences` + `clinical.GetActiveSuggestion`. JSONB shape zduplikowany świadomie w `identity-svc.preferences.preferencesPayload` i `reportprefs.Preferences` — zmiana wymiarów = update OBU w lockstep (zaznaczone w doc commentach).

#### Hardening długości raportów (zrobione w 32f9b82 + d212f38)

Pre-feature obserwacja: raporty były rozwlekłe nawet dla 2-minutowych sesji. Model wypełnia dostępne miejsce (`MaxOutputTokens = 65535`) niezależnie od długości wejścia.

- [x] **KROK 6.6:** Refaktor stałych w `cmd/llm-worker/main.go` — wyodrębnienie `geminiTempMetadata/Report`, `geminiTopP`, `geminiMaxOut*` do bloku var() obok `geminiModel/geminiRegion`. Trzy helper funkcje `metadataGenConfigJSON / metadataGenConfigMarkdown / reportGenConfig` zastępują trzy inline `vertexai.GenerationConfig{...}` literały — single source of truth dla każdego profilu samplowania.
- [x] **KROK 6.7:** Kalibracja capów MaxOutputTokens na bazie liczenia tokenów PL (~2.0 tok/słowo, ~30 tok/zdanie, ~600 tok/strona, 7 sekcji × 2-5 zdań):
  - `geminiTempReport`: 0.3 → **0.2** (dokładność > różnorodność prozy dla dokumentu klinicznego)
  - `geminiMaxOutMetadata`: 16384 → **2048** (call 1 to mały JSON, nie potrzebuje 16× headroom)
  - `geminiMaxOutReportDefault`: 65535 → **4096** (standardowy cel 2-stronnicowy ≈ 1200 effective tokenów + 3× margines)
  - `reportprefs.MaxOutputTokens`: brief 16384→**2048**, detailed 65535→**8192**
- [x] **KROK 6.8:** `reportprefs.TargetLengthDirective` — polska dyrektywa promptowa sparowana z capem ("DOCELOWA DŁUGOŚĆ RAPORTU: ~X strony (≈Y słów). Mieść się w tym budżecie z marginesem na zwięzłą formę."). Wstrzykiwana jako standalone block nad ZASADY ZWIĘZŁOŚCI w call-2 prompcie. Model honoruje explicit budżety w prompcie znacznie lepiej niż implicit hard capy.
- [x] **KROK 6.9:** Safety-retry w `generateReport` — jeśli call 2 zwróci `FinishReasonMaxTokens`, retry RAZ przy 2× capie (bounded przez `geminiMaxOutReportHardCeiling = 65535`). Loguje Warn na trigger, Error gdy retry też truncatuje (akceptuje partial output, nie loop). Belt-and-suspenders na okres rolloutu — tracked w `docs/agents/TODO.md` do usunięcia gdy trigger rate <1% przez 2 tygodnie.

- [x] **Kryteria wykonania (DoD):**
  - `go build` / `go vet` / `go test` czyste na 3 affected services.
  - Migracja 000015 stosuje się czysto na staging.
  - Ratowanie raportu zapisuje wiersz w `report_ratings` z idempotencją na `(report_id, therapist_id)`.
  - Update preferencji z `length=brief` faktycznie produkuje raport ≈1 strona (vs ≈3 dziś dla tej samej sesji) — do potwierdzenia na realnej sesji po deploy.
  - Suggestion engine: po ≥3 negatywach z kategorią `za_dlugi`, `GetActiveSuggestion` zwraca `dimension=length, to_value=brief` (lub niżej).

- [x] **Wymagane testy:** unit (preferences validators, ratings chip mapping, reportprefs rendering, suggestion engine pure logic). Eval-matrix probe na różne profile długości — odsunięte (tracked w TODO).

> **Cofalność:** Migracja down.sql gotowa (drop column + drop tables; styl-data nie jest PHI). Wycofanie samej feature po deployu = revert kodu (DB column zostaje pusta = no-op). Safety-retry można usunąć osobnym commitem gdy dane produkcyjne potwierdzą trigger rate ≈ 0%.

> **Co NIE zmienia się:** Call 1 (diaryzacja / metadane) nietknięty. Prompty modalności zablokowane (clinical baseline, ADR-IMPL-007). Pipeline labelingu mówców (ADR-IMPL-007a) niezależny. Format B transkrypt w call 2 niezmieniony. P4 (Flutter read-only on AI reports) zachowany — `RateReport` zapisuje do `report_ratings`, NIGDY do `reports`.

> Szczegóły implementacji per serwis:
> - `docs/agents/01_identity-svc.md` sekcja "Report preferences (2026-05-18)"
> - `docs/agents/02_clinical-svc.md` sekcja "Report ratings + suggestion engine (2026-05-18)"
> - `docs/agents/05_ai-pipeline-svc.md` sekcja "Report customization integration (2026-05-18)"
