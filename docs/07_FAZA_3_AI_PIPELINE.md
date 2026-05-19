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

### Priorytet 7: Pamięć długoterminowa (RAG) — pełne uzbrojenie (`feat/rag-wire`, 2026-05-19)

**Cel:** Włączyć działającą pamięć kliniczną na pacjenta. Przed dzisiejszym commitem `loadRAGContext` zwracał stub `""` i `generateEmbedding` produkował zero-vector — schemat `rag_memories` istniał, write-side dopisywał wiersze, ale read-side nigdy nie zasilał promptów. Po tej zmianie pipeline jest end-to-end.

**Tło projektowe:** ADR-002 (pgvector RAG, bez external vector store), ADR-DM-002 (envelope encryption na `summary_ciphertext`), ADR-DM-007 (CASCADE na patient_files → spełnia RODO).

#### Migration na nowy SDK (zrobione w tym samym commit'cie)

- [x] **KROK 7.0:** Migration `cloud.google.com/go/vertexai/genai` (deprecated 2025-06-24, removed 2026-06-24) → `google.golang.org/genai`. Both `llm-worker/main.go` and `llm-eval/main.go`. Struktualne delty: brak per-model objectu (config przekazywany na każde wywołanie), `Part` to struct nie interface (czyt. `part.Text` zamiast type-assertion), `EmbedContent` API dostępne pod `client.Models.EmbedContent`. Eliminuje deprecation warning na cold-startach. Pełna migracja udokumentowana w `docs/agents/05_ai-pipeline-svc.md`.

#### Producer (write-side) — Option C: RAG_Summary w Markdown call-1

Pre-feature obserwacja: w Markdown mode (`LLM_DIARIZATION_MODE=markdown`, current prod) `markdownResultToPayload` nie ustawiał `RAGSummaryChunk`. Każdy wiersz `rag_memories` od czasu Markdown flip miał empty plaintext po dekrypcji. Migration 000016 (legacy bullets cleanup, 2026-05-18) eliminowała wcześniejszą wersję bug'a (gdzie summary leakował do `report_markdown`), ale wciąż nie produkowała czystego summary.

- [x] **KROK 7.1:** Dodaj pole `RAGSummary string` do `diarization.Result`. Aktualizuj parser metadata state-machine o `ragSummaryLine` regex z aliasami (`RAG_Summary`, `RAGSummary`, `Rag_summary`, `rag_summary_chunk`) — odporne na drift modelu między ciągami. Truncacja >1500 bajtów (zamiast error) — best-effort persistence.
- [x] **KROK 7.2:** Update obu wariantów Markdown call-1 prompt'u (native + cluster) o linijkę `RAG_Summary: <streszczenie do pamięci długoterminowej, max 1500 znaków, gęsto informacyjne, BEZ danych identyfikujących...>`. Plus reguła w sekcji ZASADY: "RAG_Summary jest opcjonalne tylko gdy materiał jest zbyt krótki (≤1 chunk); inaczej WYMAGANE".
- [x] **KROK 7.3:** `markdownResultToPayload` populates `RAGSummaryChunk = r.RAGSummary || r.Summary` — fall-back zachowuje sensowny insert nawet gdy model pominie linijkę (np. małe sesje).
- [x] **KROK 7.4:** Testy parser'a: `TestParse_RAGSummary{Present, Absent, Truncated}` (3 cases) — wszystkie istniejące testy parser'a niezłamane.

#### Consumer (read-side) — real loadRAGContext

- [x] **KROK 7.5:** Real `generateEmbedding`:
  - Vertex AI `text-embedding-005` (768-dim, multilingual)
  - `client.Models.EmbedContent` z nowego SDK
  - Defensive dim check (`embeddingDims = 768` constraint)
  - Empty input → zero-vector + nil err (zachowuje stub-friendly zachowanie dla unit testów bez Vertex shim'a)
  - Non-fatal failure: caller logs Warn + skip persistRAGMemory
  - Cost: ~$0.0001 per report (jeden embed per sesja).
- [x] **KROK 7.6:** Real `loadRAGContext`:
  - Embed `currentText` (transcript surrogate, użyty jako similarity probe)
  - Two-stage CTE:
    ```sql
    WITH recent AS (
        SELECT id, summary_ciphertext, summary_encrypted_dek, embedding
        FROM rag_memories
        WHERE patient_file_id = $1 AND NOT is_compacted
        ORDER BY created_at DESC
        LIMIT 36                  -- ragLookbackMemories
    )
    SELECT id, summary_ciphertext, summary_encrypted_dek
    FROM recent
    ORDER BY embedding <=> $2::vector
    LIMIT 3                       -- ragTopK
    ```
  - Pre-filter (Stage 1): pacjent's last 36 wpisów = ~9 miesięcy weekly / ~18 miesięcy bi-weekly. Bounds search regardless of patient tenure.
  - Top-K (Stage 2): cosine distance via pgvector `<=>` operator, HNSW index covers.
  - Decrypt per row (KMS envelope), skip empties (defensive — legacy rows pre-7.1).
  - Join "1. ... 2. ... 3. ..." capped at 5000 chars total (`ragContextMaxChars`) — pod 10% call-2 input budget.
  - Background `UPDATE last_accessed_at` (best-effort, async — nie blokuje krytycznej ścieżki worker'a).
  - Non-fatal na każdym błędzie: returns `""` + err, worker dalej tworzy raport bez kontekstu.

- [x] **KROK 7.7:** Knoby w `services/ai-pipeline-svc/cmd/llm-worker/main.go` (sąsiadują dla łatwego tunningu):
  ```go
  embeddingModel       = "text-embedding-005"
  embeddingDims        = 768
  ragLookbackMemories  = 36   // candidate pool cap
  ragTopK              = 3    // hits returned
  ragContextMaxChars   = 5000 // joined output cap
  ```

#### Decyzje projektowe

- **Old-data backfill: skipped.** User confirmed test data only — historical zero-vector rows zostają. `loadRAGContext` skip-empty-plaintext logic obsługuje je gracefully (skipują ranking ale nie pollutują output).
- **Privacy:** `patient_file_id` filter w CTE = both privacy gate AND HNSW pre-filter (matches `idx_rag_memories_patient_file ON ... WHERE NOT is_compacted`). Cross-patient leakage niemożliwy. RODO erasure (CASCADE from `patient_files`) auto-wipes memorie.
- **Compaction (deferred):** schema już ma `is_compacted BOOLEAN` + `compacted_into_id UUID`. Lookback CTE filtruje `NOT is_compacted` → kiedy job compaction wyląduje (post-launch, gdy zaobserwujemy patientów >36 sessions), żadna zmiana read-side nie będzie potrzebna.

- [x] **Kryteria wykonania (DoD):**
  - `go build` / `go vet` / unit testy czyste na ai-pipeline-svc.
  - 3 nowe parser testy (`RAGSummary*`) green.
  - Deploy llm-worker via standard pattern (trigger-service-account + retry flagi, per runbook w `docs/agents/07_devops-cicd.md`).
  - E2E `TestFullSession_HappyPath` Step 7 zielony — krytyczny smoke test: nowy SDK + nowy embedding call + nowy RAG read.
  - Fresh patient → `rag_summary_chunk` populated w nowym raporcie (verify via `dump-report` CLI jeśli potrzeba).

- [x] **Wymagane testy:** unit (parser RAGSummary x 3). E2E happy-path (Step 7) — first-session-per-patient pokrywa empty-result branch `loadRAGContext`'a. Multi-session e2e dla populated-branch — odsunięte (wymaga compaction job lub explicit dual-session fixture; tracked w TODO).

> **Cofalność:** Pełny rollback przez deploy poprzedniej revision llm-worker. Schemat `rag_memories` niezmieniony (był od 000007); `RAGSummary` field w `diarization.Result` jest dodatkowy (nie usuwany przez stary kod). Stara revision will produce zero-vector embeds + empty RAGSummaryChunk again — degraduje do pre-feature behavior bez data loss.

> **Co NIE zmienia się:** Schemat `rag_memories` (001 created w 000007). Pipeline transkryptu / diaryzacji / Format A vs B (ADR-IMPL-002, ADR-IMPL-007) nietknięty. Modality prompts (000008) niezmienione — RAG_Summary prompt'owe instructions są w `cmd/llm-worker/main.go::callMetadataMarkdown`, nie w DB. P4 (Flutter read-only) zachowany.

> Szczegóły implementacji + failure modes table + cost analysis:
> - `docs/agents/05_ai-pipeline-svc.md` sekcja "Long-term memory (RAG) — wired 2026-05-19"

#### Hardening długości raportów — 3× headroom cap bump (`feat/cap-bump`, 2026-05-19 pm)

Pre-feature obserwacja: na sesji `0a5523a0` (modality PPT, prefs `length=standard` + `section_emphasis=[wszystkie 7 sekcji]`) call-2 dwukrotnie hit MaxOutputTokens i przyjął truncated output. Logi llm-worker:

```
12:32:18  call 2 hit MaxOutputTokens — retrying once at 2× cap
12:33:05  call 2 hit MaxOutputTokens twice — accepting truncated output
```

Root cause: cap był ustawiony NA target dyrektywy promptowej, więc 10–20% overshoot modelu wystarczał, żeby wystrzelić safety-retry. Retry przy 2× cap też hit limit (typowa sekwencja: pierwszy call 3411 tok → cap 4096; retry 8192 → też za mało dla user'a z 7 wymuszonymi sekcjami). Każde takie zdarzenie = ~3× koszt sesji + ~2.5× latency.

Decision: caps mają być remote safety net, NIE budżetem do którego model się "ściga". Dyrektywa promptowa (`TargetLengthDirective`) faktycznie kształtuje długość — caps tylko ją osłaniają.

- [x] **KROK 7.8 (caps 3× headroom):** Bump default caps trzykrotnie nad target dyrektywy:
  - `geminiMaxOutReportDefault`: 4096 → **12288**
  - `reportprefs.MaxOutputTokens(brief)`: 2048 → **6144**
  - `reportprefs.MaxOutputTokens(detailed)`: 8192 → **24576**
  - Koszt impact: ZERO (Vertex bills on actual emitted tokens, not cap). Headroom = insurance.

- [x] **KROK 7.9 (section_emphasis budget scaling):** Każda emphasized sekcja dodaje 500 tok do cap'a (`MaxOutputTokens += n * 500`), soft ceiling 32768 (well below `geminiMaxOutReportHardCeiling=65535`). Naprawia produktową sprzeczność: pre-feature user mógł zaznaczyć `section_emphasis=[7 sekcji]` + `length=standard`, ale cap pozostawał na 4096 → gwarantowana truncacja. Po fix user'ów case ląduje na `12288 + 7×500 = 15788`, well above the model's natural ~5000-6000 emission.

- [x] **KROK 7.10 (safety-retry 2× → 4×):** Multiplier bumped on both call-1 + call-2 retry paths. Z 3×-headroom default'ami retry zasadniczo nie powinno firować — ale jeśli firuje, 2× często sięga limitu ponownie (obserwacja: session `0a5523a0`, oba calle truncated). 4× daje retry'owi prawdziwy budżet. Clamped at `geminiMaxOutReportHardCeiling=65535`.

- [x] **KROK 7.11 (force markdown blockquote dla cytatów):** Call-2 prompt explicitly forbids label-form (`**Cytat:** "..."` / `**Quote:** "..."`) i wymaga `> "..."` on its own line:

  > "Render each quote as a markdown blockquote on its own line, prefixed with '> ' (greater-than + space). DO NOT use the label form. Even if the modality template suggests a label form, override it and use '> '."

  Pre-fix: PPT modality prompt example pattern (`**Cytat:**`) wygrywał z mojej wcześniejszej "blockquotes OR quote marks" allowance → Flutter renderer (który styluje only `> ...`) lost the visual treatment. Naprawione przez explicit ban + ovveride mandate.

#### Call-1 nie dostaje RAG context (`feat/rag-call1-drop`, 2026-05-19 pm)

Pre-feature: `ragContext` był threadowany do obu callsów: call-1 (metadata + diarization) i call-2 (clinical report). Reasoning behind drop: wszystkie 6 outputów call-1 (title, summary_short, RAG_Summary, speaker clustering, role inference, overall_confidence) opisują TĘ sesję. Prior context może tylko zaszkodzić:

| call-1 output | Co psuje prior context |
|---|---|
| title | Numeracja-style continuity ("Druga sesja…") — get ordering wrong (mamy `created_at`). |
| summary_short | Self-contained recap; RAG injection powodował referencowanie wcześniejszych sesji wewnątrz tego summary. |
| RAG_Summary | Nowy wpis pamięci długoterminowej — priming wcześniejszymi powodował multiplikację treści + drop unique signal. |
| Speaker clustering | Czysta analiza zawartości transkryptu; prior context mógł biasować labels do "therapist/patient" z wcześniejszych sesji nawet jeśli ta sesja ma inną kompozycję mówców. |
| overall_diarization_confidence | Czysta speaker-tag math. Nieistotne. |

- [x] **KROK 7.12:** Drop `ragContext` z `callMetadataJSON` i `callMetadataMarkdown` (oba grammar variants). `KONTEKST POPRZEDNICH SESJI:` heading + placeholder usunięte z trzech promptów call-1. Call-2 (`generateReport`) wciąż otrzymuje ragContext — to tam clinical synthesis genuinely needs cross-session continuity.

- [x] **KROK 7.13:** Self-containment reminders dodane do ZASADY w każdym call-1 promptcie:
  - "title: ... Opisuje TĘ sesję, nie buduj numeracji ani kontynuacji z wcześniejszych spotkań."
  - "summary_short: ... Samodzielne streszczenie TEJ sesji — nie odwołuj się do wcześniejszych spotkań."
  - "rag_summary_chunk: ... Nie powtarzaj treści wcześniejszych podsumowań — niech wpis będzie samodzielnym śladem tej sesji."

`loadRAGContext` wciąż firuje raz na top of `ProcessTranscript` — embedding/decrypt to koszt; using result once vs twice is free at that point.

- [x] **Kryteria wykonania (DoD):**
  - go build / go vet / unit testy zielone (TestMaxOutputTokens rozszerzony o 6 sub-cases dla section_emphasis scaling).
  - Deploy llm-worker standardową ścieżką (trigger-service-account + retry flagi).
  - E2E 12/12 PASS — zarówno przed (bs8athxq3t) i po (bigy5sqwb, b8athxq3t, follow-up) były zielone.
  - Verification on production data: patient `para znowu test Raga` (4 sessions, ostatnia 13:29 UTC) — `rag_memories` shows all 4 wierszy z real 768-dim vectors (distance from zero-vec ~0.9999) + non-empty plaintext (~700-1000 bajtów summary_ciphertext). `last_accessed_at` bumps prove session 4 retrieved 1-3 jako candidates.

> **Cofalność:** Wszystkie 4 zmiany cofalne przez deploy poprzedniej revision llm-worker. Caps bump jest soft-tunable przez `geminiMaxOut*` consts; section_emphasis scaling — single function. Call-1 RAG drop — restoration to przywrócenie `ragContext` parametru + `KONTEKST POPRZEDNICH SESJI:` block do 3 promptów.

> **Co NIE zmienia się:** ADR-IMPL-007 (LLM-inferred diarization). `rag_memories` schemat. Modality prompts (DB-stored, migration 000008). Call-2 prompt RAG injection point (`KONTEKST POPRZEDNICH SESJI:`). Flutter rendering layer (call-2 prompt enforces `> ...` shape — to is what `flutter_markdown` blockquote styling expects).
