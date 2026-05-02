# 🎙️ Faza 2 — Ingestion + AI Pipeline (Tygodnie 5-7)

**Wersja:** 1.1
**Status:** Implementation guide. Zgodne z architekturą `02_ARCHITEKTURA_TECHNICZNA.md`, modelem danych `03_DATA_MODEL.md` v4.3, oraz fundamentem z `04_FAZA_0_FUNDAMENT.md` i `05_FAZA_1_TOZSAMOSC_DANE.md`.

## 📝 Changelog v1.0 → v1.1

**1. Neutralne speaker labels zamiast role-mapping w STT.**
STT worker NIE rozpoznaje już ról (terapeuta/pacjent). Generuje neutralne, lokalizowane etykiety: `Osoba 1`/`Osoba 2` (pl), `Person 1`/`Person 2` (en), itd. dla 85+ języków Chirp 3. Role wynikną z analizy LLM, który ma kontekst rozmowy.

**2. Schema change: `speaker_role` → `speaker_label` + `speaker_tag`.**
Tabela `transcript_segments`: kolumna `speaker_role user_role` zastąpiona przez `speaker_label VARCHAR(50)` (np. `"Osoba 1"`). Tabela `sessions`: `speaker_role_mapping` → `speaker_label_mapping`. Brak enum constraints — pełna elastyczność.

**3. Opcja B: blob `transcripts.transcript_ciphertext` jest kanoniczny.**
Pełen tekst transkryptu jest zaszyfrowanym JSON-em w `transcripts`. Tabela `transcript_segments` służy tylko do statystyk (word counts per speaker, duration, segment-level confidence) i triggeruje rebuild blob'a gdy zmieni się mapping. Flutter czyta zawsze z `transcripts`, nie z `transcript_segments`.

**4. Nowy pakiet `pkg/i18n/speakerlabels`.**
Centralny słownik etykiet per locale. Fallback `Speaker N` (English) dla nieznanych locale.

**5. Procedura rebuild blob.**
Nowy gRPC endpoint `clinical-svc.UpdateSpeakerLabels` aktualizuje `sessions.speaker_label_mapping`, regeneruje `transcripts.transcript_ciphertext` z `transcript_segments` w jednej transakcji.
**Owner:** Senior Backend + Flutter dev + ML/AI engineer
**Czas trwania:** 15 dni roboczych (3 tygodnie)
**Cel fazy:** Postawić pełen pipeline od nagrania w Flutter, przez upload do Cloud Storage, transkrypcję (Chirp 3 z diarization), analizę przez Gemini 2.5 PRO, wyodrębnienie HiTOP measurements i zapis embeddings do RAG memory. **billing-svc** jest stubem zwracającym OK — pełna integracja Stripe w Fazie 3.

---

## 📋 Spis treści

1. [Definition of Done](#definition-of-done)
2. [Decyzje architektoniczne i zmiany względem oryginalnego planu](#decyzje-architektoniczne-i-zmiany)
3. [Sprint planning](#sprint-planning)
4. [Sprint 2.1 — Migracje DDL: Audio + Sessions + AI](#sprint-21--migracje-ddl)
5. [Sprint 2.2 — Cloud Storage + ingestion-svc](#sprint-22--cloud-storage--ingestion-svc)
6. [Sprint 2.3 — billing-svc (stub)](#sprint-23--billing-svc-stub)
7. [Sprint 2.4 — Pub/Sub topics + subscriptions](#sprint-24--pubsub)
8. [Sprint 2.5 — STT worker (Chirp 3 + diarization)](#sprint-25--stt-worker)
9. [Sprint 2.6 — LLM worker (Gemini PRO + HiTOP + RAG)](#sprint-26--llm-worker)
10. [Sprint 2.7 — Flutter recording module](#sprint-27--flutter-recording-module)
11. [Sprint 2.8 — E2E test pełnego pipeline'u](#sprint-28--e2e-test)
12. [Troubleshooting cookbook](#troubleshooting-cookbook)
13. [Pre-Faza 3 checklist](#pre-faza-3-checklist)

---

## Definition of Done

Faza 2 jest "done" kiedy spełnione są WSZYSTKIE poniższe:

- [ ] Migracje DDL `000007_audio.up.sql`, `000008_sessions.up.sql`, `000009_ai_pipeline.up.sql`, `000010_rag_memory.up.sql` zaaplikowane.
- [ ] Cloud Storage bucket `superwizor-audio-uploads` z OLM 48h, CMEK, uniform bucket-level access, public access prevention.
- [ ] **ingestion-svc** deployowany; zwraca signed URL na request, weryfikuje `recording_consent` i kwotę miesięczną.
- [ ] **billing-svc stub** deployowany; `CheckQuota` zwraca `allowed=true` zawsze (mock).
- [ ] **ai-pipeline-svc** zawiera 2 Cloud Functions Gen2:
  - `stt-worker` reaguje na Pub/Sub topic `audio.uploaded`, używa Chirp 3 z diarization, generuje **neutralne lokalizowane labels** (`Osoba 1` / `Person 1` / itd.) na podstawie `language_code` z pakietu `pkg/i18n/speakerlabels`. Zapisuje kanoniczny blob w `transcripts` + statystyki w `transcript_segments`.
  - `llm-worker` reaguje na `transcript.completed`, ładuje RAG context, wywołuje Gemini 3.1 FLASH ze structured output, **deduces role per speaker_tag** (zapis w `reports.speaker_role_inference` JSONB), zapisuje `reports`, `hitop_measurements`, embeddings do `rag_memory`.
- [ ] **clinical-svc.UpdateSpeakerLabels** endpoint działa: terapeuta zmienia `Osoba 1 → Anna`, blob `transcripts.transcript_ciphertext` jest atomicznie regenerowany.
- [ ] Flutter recording module:
  - Wakelock włączony podczas nagrywania.
  - Audio chunking co 30s do plików `.m4a`.
  - Upload przez signed URL (PUT request) z retry policy.
  - Progress indicator i error handling.
- [ ] **E2E test:** Flutter nagrywa 90s testowego dialogu → upload → STT → LLM → raport widoczny w aplikacji w < 4 min.
- [ ] Pub/Sub Dead Letter Queue skonfigurowane dla wszystkich subscriptions.
- [ ] Pipeline logs widoczne w Cloud Logging z `session_id` jako label.
- [ ] Test coverage ≥ 70% dla wszystkich nowych serwisów.

---

## Decyzje architektoniczne i zmiany

### ADR-IMPL-001: Chirp 3 zamiast Chirp 2

**Kontekst:** Oryginalna architektura zakładała Chirp 2.

**Problem:** Chirp 2 **NIE supportuje speaker diarization**. To kluczowy wymóg w Fazie 2 (rozróżnienie terapeuta vs pacjent w transkrypcie).

**Decyzja:** Używamy **Chirp 3: Transcription** (GA od 2025) z włączonym `enable_speaker_diarization`. Model identifier: `chirp_3`.

**Konsekwencje:**
- Pricing podobny do Chirp 2 (~$0.016/min audio).
- Region: Chirp 3 dostępne w `us-central1`, `europe-west4`, `asia-southeast1` — Chirp 3 NIE jest dostępne w `europe-central2`!
- **Mitigation dla "Żelaznej Lokalizacji":** Wywołania STT wykonujemy z `europe-west4` (najbliższy europejski region z Chirp 3, w UE). Audio jest tymczasowo replikowane przy wywołaniu API. To akceptowalny kompromis: dane pozostają w UE, RODO compliance zachowane (Google jako processor + DPA).
- W `02_ARCHITEKTURA_TECHNICZNA.md` (sekcja 17 Risk Register) trzeba dodać explicit risk + mitigation dla tego cross-region call.

### ADR-IMPL-002: Neutralne lokalizowane speaker labels (bez heurystyki ról w STT)

**Kontekst:** Chirp 3 zwraca anonimowe `speaker_tag` (1, 2, 3...). Wcześniejsza wersja zakładała heurystykę "pierwsza wypowiedź ≥5s = THERAPIST".

**Problem:** Heurystyka jest zawodna (np. terapeuta zaczyna od krótkiego pytania, pacjent odpowiada długim monologiem). Forsowanie ról w STT powoduje błędy które potem trzeba korygować ręcznie. Dodatkowo dla sesji par/rodzin (process_type = COUPLE/FAMILY) są więcej niż 2 osoby i klasyfikacja therapist/patient nie pasuje.

**Decyzja:** STT worker generuje **wyłącznie neutralne, lokalizowane etykiety**:

| `language_code` | `speaker_tag=1` | `speaker_tag=2` | `speaker_tag=3` |
|-----------------|-----------------|-----------------|-----------------|
| `pl-PL` | `Osoba 1` | `Osoba 2` | `Osoba 3` |
| `en-US`, `en-GB` | `Person 1` | `Person 2` | `Person 3` |
| `de-DE` | `Person 1` | `Person 2` | `Person 3` |
| `es-ES`, `es-US` | `Persona 1` | `Persona 2` | `Persona 3` |
| `fr-FR`, `fr-CA` | `Personne 1` | `Personne 2` | `Personne 3` |
| `it-IT` | `Persona 1` | `Persona 2` | `Persona 3` |
| `pt-BR`, `pt-PT` | `Pessoa 1` | `Pessoa 2` | `Pessoa 3` |
| `nl-NL` | `Persoon 1` | `Persoon 2` | `Persoon 3` |
| `ru-RU` | `Человек 1` | `Человек 2` | `Человек 3` |
| `uk-UA` | `Особа 1` | `Особа 2` | `Особа 3` |
| `cs-CZ` | `Osoba 1` | `Osoba 2` | `Osoba 3` |
| `sk-SK` | `Osoba 1` | `Osoba 2` | `Osoba 3` |
| `hu-HU` | `Személy 1` | `Személy 2` | `Személy 3` |
| `ro-RO` | `Persoana 1` | `Persoana 2` | `Persoana 3` |
| `tr-TR` | `Kişi 1` | `Kişi 2` | `Kişi 3` |
| ja-JP | `話者1` | `話者2` | `話者3` |
| ko-KR | `화자 1` | `화자 2` | `화자 3` |
| `cmn-CN` | `说话人 1` | `说话人 2` | `说话人 3` |
| `ar-XA` | `متحدث 1` | `متحدث 2` | `متحدث 3` |
| **fallback (unknown locale)** | `Speaker 1` | `Speaker 2` | `Speaker 3` |

Pełen słownik jest w pakiecie `pkg/i18n/speakerlabels`. Locale wykryty automatycznie przez Chirp 3 (`auto_detect_languages`) lub explicit z `session.language_code`.

**Role (terapeuta/pacjent/dziecko/partner) są dedukowane przez LLM** w trakcie analizy raportu na podstawie kontekstu rozmowy — kto pyta, kto opisuje objawy, kto stosuje techniki terapeutyczne. LLM dostaje transkrypt z neutralnymi labels i sam pisze w raporcie "Osoba 1 prawdopodobnie pełni rolę terapeuty na podstawie wzorców pytań i interwencji".

**Konsekwencje:**
- Brak fałszywych przypisań ról dla nietypowych sesji.
- Naturalne wsparcie sesji par/rodzin/grup (3+ mówców).
- Terapeuta może w UI ręcznie zmienić labels (`Osoba 1 → Anna`, `Osoba 2 → Marek`) — przez endpoint `UpdateSpeakerLabels`.
- LLM raport zawiera explicit attribution z evidence (np. *"Osoba 1, prawdopodobnie terapeuta, zastosowała technikę socratic questioning w segmencie 02:15-03:40"*).

### ADR-IMPL-003: Gemini 3.1 FLASH przez Vertex AI

**Kontekst:** Decyzja modelu LLM dla pipeline'u.

**Decyzja:** **Gemini 3.1 FLASH przez Vertex AI** (nie public Gemini API):
- Region `europe-west4` (sąsiad europe-central2, dostępny w UE).
- Structured output via `response_schema` (JSON Schema, supported od Gemini 2.0+).
- Auth przez Workload Identity (zero JSON keys).


### ADR-IMPL-004: Cloud Functions Gen2 jako workery

**Kontekst:** STT i LLM workers — Cloud Run Job vs Cloud Functions Gen2 vs Cloud Run service.

**Decyzja:** **Cloud Functions Gen2** (które są Cloud Run pod spodem) + Eventarc → Pub/Sub trigger. Dlaczego:
- Native Pub/Sub integration (nie trzeba HTTP push subscription).
- Auto-retry + DLQ wbudowane.
- Per-invocation billing (nie płacimy za idle time).
- Concurrency limit per function (chronimy przed thundering herd przy spike'u).

### ADR-IMPL-005: billing-svc jako stub

**Kontekst:** Stripe integration to duża praca; nie chcemy blokować pipeline'u.

**Decyzja:** **billing-svc w Fazie 2 zwraca zawsze `allowed=true`** dla `CheckQuota`. Pełna integracja Stripe webhook + quota tracking w Fazie 3. Schema DB dla `subscriptions`, `usage_quotas`, `payment_events` POZOSTAJE z modelu v4.3 — tylko logika biznesowa jest mock.

### ADR-IMPL-006: `transcripts.transcript_ciphertext` jest source of truth (Opcja B)

**Kontekst:** Pełen tekst transkryptu może być przechowywany jako (a) jeden blob w `transcripts`, (b) tylko jako wiersze `transcript_segments`, (c) blob jako materialized cache nad segmentami. Wcześniejsza wersja v1.0 miała jednocześnie blob i segmenty z duplikującymi się danymi — bez jasnej decyzji który jest kanoniczny.

**Decyzja:** **Blob `transcripts.transcript_ciphertext` jest kanoniczny.** Tabela `transcript_segments` służy do:
- statystyk per-speaker (`text_word_count`, `start_offset_ms`, `end_offset_ms`, `confidence`),
- audytu i debugging diarization,
- generowania nowego blob'a po zmianie `speaker_label_mapping` (rebuild flow).

**Flutter ZAWSZE czyta `transcripts`** — jeden KMS decrypt zwraca pełen tekst gotowy do wyświetlenia. Frontend NIE pobiera `transcript_segments` w głównym flow odczytu.

**Rebuild blob — kiedy:**
- Po pierwotnej transkrypcji (STT worker zapisuje blob + segmenty atomicznie).
- Po wywołaniu `clinical-svc.UpdateSpeakerLabels` (terapeuta zmienia "Osoba 1" → "Anna"): worker odczytuje wszystkie segmenty, podstawia nowe labels, zapisuje nowy blob.

**Konsekwencje:**
- Pełen tekst do LLM = jeden decrypt KMS (~30ms) zamiast N decrypts.
- Pełen tekst do Flutter = jeden decrypt + transmission (BYTEA → frontend).
- Korekta labels = atomic transaction (UPDATE sessions + UPDATE transcripts + INSERT audit_event).
- Storage overhead ~30-50KB per sesja — akceptowalne.
- Konsystencja: trigger PostgreSQL pilnuje że nie da się update'ować `transcript_segments.speaker_label` bez rebuilding blob'a (zob. DDL).

**Pseudokod rebuild:**

```go
func RebuildTranscriptBlob(ctx, transcriptID, newLabelMapping) error {
    tx := db.Begin()

    // 1. Load all segments
    segments := tx.Query("SELECT speaker_tag, text_ciphertext, start_offset_ms, end_offset_ms FROM transcript_segments WHERE transcript_id = $1 ORDER BY start_offset_ms", transcriptID)

    // 2. Decrypt each segment text + apply new labels
    fullText := []TranscriptLine{}
    for s := range segments {
        text := kms.Decrypt(s.text_ciphertext, s.text_encrypted_dek)
        label := newLabelMapping[s.speaker_tag]
        fullText = append(fullText, TranscriptLine{
            SpeakerTag: s.speaker_tag,
            SpeakerLabel: label,
            Text: text,
            StartMS: s.start_offset_ms,
            EndMS: s.end_offset_ms,
        })
    }

    // 3. Marshal + encrypt new blob
    blobJSON := json.Marshal(fullText)
    newCiphertext, newDEK := kms.Encrypt(blobJSON)

    // 4. Update transcripts
    tx.Exec("UPDATE transcripts SET transcript_ciphertext = $1, transcript_encrypted_dek = $2, blob_rebuilt_at = now() WHERE id = $3", newCiphertext, newDEK, transcriptID)

    // 5. Update transcript_segments.speaker_label for visibility w stats
    for tag, label := range newLabelMapping {
        tx.Exec("UPDATE transcript_segments SET speaker_label = $1 WHERE transcript_id = $2 AND speaker_tag = $3", label, transcriptID, tag)
    }

    tx.Commit()
}
```

---

## Sprint planning

```
Tydzień 5                 Tydzień 6                 Tydzień 7
┌──────┬──────┬──────┐    ┌──────┬──────┬──────┐    ┌──────┬──────┬──────┐
│ 2.1  │ 2.2  │ 2.3  │    │ 2.4  │ 2.5  │ 2.5  │    │ 2.6  │ 2.7  │ 2.8  │
│Migr  │Inges │Bill  │    │PubSub│STT   │STT   │    │LLM   │Fluttr│ E2E  │
│ DDL  │tion  │stub  │    │      │worker│cd    │    │worker│recrd │      │
└──────┴──────┴──────┘    └──────┴──────┴──────┘    └──────┴──────┴──────┘
```

### Dependencies

```
Sprint 2.1 (DDL) ──► Sprint 2.2 (ingestion + bucket) ──┐
                          │                            │
                          ▼                            │
                    Sprint 2.3 (billing stub)          │
                          │                            ▼
                          └─────────► Sprint 2.4 (Pub/Sub) ──► Sprint 2.5 (STT)
                                                               │
                                                               ▼
                                                         Sprint 2.6 (LLM)
                                                               │
                                                               ▼
                                                         Sprint 2.7 (Flutter)
                                                               │
                                                               ▼
                                                         Sprint 2.8 (E2E)
```

### Owner & accountability

| Sprint | Primary | Estimate |
|--------|---------|----------|
| 2.1 Migracje | Senior backend | 2 dni |
| 2.2 Ingestion | Senior backend + DevOps | 2 dni |
| 2.3 Billing stub | Backend dev | 1 dzień |
| 2.4 Pub/Sub | DevOps | 1 dzień |
| 2.5 STT worker | ML eng + backend | 2 dni |
| 2.6 LLM worker | ML eng + senior backend | 3 dni |
| 2.7 Flutter | Flutter dev | 2 dni |
| 2.8 E2E | DevOps + tech lead | 2 dni |

---

## Sprint 2.1 — Migracje DDL

**Czas:** 2 dni
**Cel:** DDL dla domen Audio, Sessions, AI Pipeline (transcripts + reports + HiTOP), RAG Memory.

### Task 2.1.1 — Migracja 000007: Audio uploads

```bash
make migrate-create NAME=audio

cat > migrations/000007_audio.up.sql <<'EOF'
-- ============================================
-- AUDIO UPLOADS (krótko-żyjące, OLM 48h)
-- ============================================
CREATE TABLE audio_uploads (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    therapist_id        UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    patient_file_id     UUID NOT NULL REFERENCES patient_files(id) ON DELETE RESTRICT,
    session_id          UUID,  -- FK dodany po utworzeniu sessions

    bucket_name         VARCHAR(255) NOT NULL,
    object_path         VARCHAR(500) NOT NULL UNIQUE,
    content_type        VARCHAR(100) NOT NULL DEFAULT 'audio/m4a',
    file_size_bytes     BIGINT,
    duration_seconds    INTEGER,
    sample_rate_hz      INTEGER,
    chunk_count         INTEGER NOT NULL DEFAULT 1,

    status              upload_status NOT NULL DEFAULT 'PENDING',
    upload_started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    upload_completed_at TIMESTAMPTZ,
    expires_at          TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '48 hours'),

    -- Idempotency key dla retries
    idempotency_key     VARCHAR(128) UNIQUE,

    -- Klient meta (debug)
    client_app_version  VARCHAR(50),
    client_platform     VARCHAR(20),  -- 'ios', 'android'

    error_message       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audio_uploads_therapist ON audio_uploads(therapist_id, status);
CREATE INDEX idx_audio_uploads_session ON audio_uploads(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX idx_audio_uploads_expires ON audio_uploads(expires_at) WHERE status != 'EXPIRED';
EOF

cat > migrations/000007_audio.down.sql <<'EOF'
DROP TABLE IF EXISTS audio_uploads;
EOF
```

### Task 2.1.2 — Migracja 000008: Sessions

```bash
make migrate-create NAME=sessions

cat > migrations/000008_sessions.up.sql <<'EOF'
-- ============================================
-- SESSIONS
-- ============================================
CREATE TABLE sessions (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    therapist_id                UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    patient_file_id             UUID NOT NULL REFERENCES patient_files(id) ON DELETE RESTRICT,
    audio_upload_id             UUID REFERENCES audio_uploads(id) ON DELETE SET NULL,

    session_date                DATE NOT NULL,
    session_number              INTEGER NOT NULL,
    duration_seconds            INTEGER,
    contact_form                contact_form NOT NULL DEFAULT 'OFFICE',

    -- Speaker labels mapping (zob. ADR-IMPL-002)
    -- Format: {"1": "Osoba 1", "2": "Osoba 2", "3": "Anna"} (ostatni po manual override)
    -- Domyślnie generowane przez STT z pkg/i18n/speakerlabels na podstawie language_code.
    speaker_label_mapping       JSONB NOT NULL DEFAULT '{}'::jsonb,

    -- Język wykryty/explicit dla tej sesji (do generowania labels)
    language_code               VARCHAR(10),

    therapist_observations      TEXT,
    is_consent_confirmed        BOOLEAN NOT NULL DEFAULT FALSE,

    status                      session_status NOT NULL DEFAULT 'CREATED',
    status_updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    error_message               TEXT,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
    deleted_at                  TIMESTAMPTZ,

    CONSTRAINT chk_session_number_positive CHECK (session_number > 0)
);

CREATE INDEX idx_sessions_therapist_date ON sessions(therapist_id, session_date DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_sessions_patient_file ON sessions(patient_file_id, session_number) WHERE deleted_at IS NULL;
CREATE INDEX idx_sessions_status ON sessions(status, status_updated_at) WHERE deleted_at IS NULL;
CREATE UNIQUE INDEX idx_sessions_patient_file_number ON sessions(patient_file_id, session_number) WHERE deleted_at IS NULL;

-- Deferred FK from audio_uploads
ALTER TABLE audio_uploads
    ADD CONSTRAINT fk_audio_uploads_session
    FOREIGN KEY (session_id) REFERENCES sessions(id) ON DELETE SET NULL;
EOF

cat > migrations/000008_sessions.down.sql <<'EOF'
ALTER TABLE audio_uploads DROP CONSTRAINT IF EXISTS fk_audio_uploads_session;
DROP TABLE IF EXISTS sessions;
EOF
```

### Task 2.1.3 — Migracja 000009: AI Pipeline (transcripts + reports + HiTOP)

```bash
make migrate-create NAME=ai_pipeline

cat > migrations/000009_ai_pipeline.up.sql <<'EOF'
-- ============================================
-- TRANSCRIPTS (blob jest kanoniczny — Opcja B, ADR-IMPL-006)
-- ============================================
CREATE TABLE transcripts (
    id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id               UUID NOT NULL REFERENCES sessions(id) ON DELETE RESTRICT,

    -- KANONICZNY pełen tekst transkryptu — Flutter czyta z tego pola
    -- JSON: [{"speaker_tag": 1, "speaker_label": "Osoba 1", "text": "...", "start_ms": 1200, "end_ms": 4500}, ...]
    transcript_ciphertext    BYTEA NOT NULL,
    transcript_encrypted_dek BYTEA NOT NULL,

    -- Metadata (nie zaszyfrowane)
    language_code            VARCHAR(10) NOT NULL,
    word_count               INTEGER,
    speaker_count            INTEGER,
    confidence_avg           NUMERIC(4, 3),

    stt_model                VARCHAR(50) NOT NULL,  -- 'chirp_3'
    stt_processed_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
    stt_processing_seconds   INTEGER,

    -- Rebuild tracking
    blob_rebuilt_at          TIMESTAMPTZ,
    blob_rebuild_count       INTEGER NOT NULL DEFAULT 0,

    created_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_transcripts_session ON transcripts(session_id);

-- ============================================
-- TRANSCRIPT SEGMENTS (per-speaker, per-utterance — STATYSTYKI + REBUILD source)
-- Flutter ich nie czyta. Backend używa do (1) statystyk per-speaker,
-- (2) rebuildowania transcript_ciphertext po zmianie labels.
-- ============================================
CREATE TABLE transcript_segments (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transcript_id       UUID NOT NULL REFERENCES transcripts(id) ON DELETE CASCADE,

    -- Z Chirp 3 (1, 2, 3...)
    speaker_tag         INTEGER NOT NULL,

    -- Lokalizowana etykieta: "Osoba 1" / "Person 1" / "Anna" (po manual override)
    -- NIE jest enum — pełna elastyczność (terapeuta może wpisać prawdziwe imię)
    speaker_label       VARCHAR(50) NOT NULL,

    start_offset_ms     INTEGER NOT NULL,
    end_offset_ms       INTEGER NOT NULL,

    -- Encrypted text segmentu (per-segment encryption dla granular access patterns)
    text_ciphertext     BYTEA NOT NULL,
    text_encrypted_dek  BYTEA NOT NULL,
    text_word_count     INTEGER,

    confidence          NUMERIC(4, 3),

    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_transcript_segments_transcript ON transcript_segments(transcript_id, start_offset_ms);
CREATE INDEX idx_transcript_segments_speaker_tag ON transcript_segments(transcript_id, speaker_tag);

-- ============================================
-- REPORTS (LLM output)
-- ============================================
CREATE TABLE reports (
    id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id                  UUID NOT NULL REFERENCES sessions(id) ON DELETE RESTRICT,
    transcript_id               UUID NOT NULL REFERENCES transcripts(id) ON DELETE RESTRICT,
    modality_id                 UUID NOT NULL REFERENCES modalities(id) ON DELETE RESTRICT,

    -- Encrypted JSON z całym raportem (struktura zależy od modality)
    report_ciphertext           BYTEA NOT NULL,
    report_encrypted_dek        BYTEA NOT NULL,

    -- Sumarycznie (nie zaszyfrowane, do listingów)
    title                       VARCHAR(500),
    summary_short               TEXT,         -- ≤ 500 chars, do listingów
    sentiment_label             VARCHAR(50),  -- 'positive', 'neutral', 'concerning'
    risk_level                  VARCHAR(50),  -- 'low', 'medium', 'high'

    -- LLM-deduced role inference (zapisane jako JSONB)
    -- Format: {"1": {"role": "therapist", "confidence": 0.92, "evidence": "uses socratic questioning"},
    --         "2": {"role": "patient", "confidence": 0.95, "evidence": "describes anxiety symptoms"}}
    speaker_role_inference      JSONB NOT NULL DEFAULT '{}'::jsonb,

    llm_model                   VARCHAR(100) NOT NULL,  -- 'gemini-2.5-pro'
    llm_input_tokens            INTEGER,
    llm_output_tokens           INTEGER,
    llm_processing_seconds      INTEGER,
    llm_total_cost_usd          NUMERIC(10, 6),

    -- For "regenerate" flows in future
    parent_report_id            UUID REFERENCES reports(id) ON DELETE SET NULL,
    generation_count            INTEGER NOT NULL DEFAULT 1,

    created_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_reports_session ON reports(session_id);
CREATE INDEX idx_reports_modality ON reports(modality_id, created_at DESC);

-- ============================================
-- HITOP MEASUREMENTS
-- ============================================
-- Closed ontology of HiTOP dimensions (placeholder; pełna lista po konsultacji klinicznej)
CREATE TABLE hitop_dimensions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            VARCHAR(50) NOT NULL UNIQUE,
    display_name    VARCHAR(255) NOT NULL,
    parent_code     VARCHAR(50),
    description     TEXT,
    level           VARCHAR(20) NOT NULL,  -- 'spectrum', 'subfactor', 'syndrome', 'symptom'
    is_active       BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_hitop_dimensions_parent ON hitop_dimensions(parent_code);

CREATE TABLE hitop_measurements (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id          UUID NOT NULL REFERENCES sessions(id) ON DELETE RESTRICT,
    report_id           UUID NOT NULL REFERENCES reports(id) ON DELETE CASCADE,
    dimension_id        UUID NOT NULL REFERENCES hitop_dimensions(id) ON DELETE RESTRICT,

    -- Skala 0-100 z confidence
    score               NUMERIC(5, 2) NOT NULL,
    confidence          NUMERIC(4, 3) NOT NULL,

    -- Evidence: cytaty z transkryptu (encrypted, krótkie ≤ 200 chars each)
    evidence_ciphertext BYTEA,
    evidence_encrypted_dek BYTEA,

    measured_at         TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_score_range CHECK (score >= 0 AND score <= 100),
    CONSTRAINT chk_confidence_range CHECK (confidence >= 0 AND confidence <= 1)
);

CREATE INDEX idx_hitop_measurements_session ON hitop_measurements(session_id);
CREATE INDEX idx_hitop_measurements_dimension ON hitop_measurements(dimension_id, measured_at DESC);
CREATE UNIQUE INDEX idx_hitop_measurements_unique ON hitop_measurements(session_id, dimension_id);
EOF

cat > migrations/000009_ai_pipeline.down.sql <<'EOF'
DROP TABLE IF EXISTS hitop_measurements;
DROP TABLE IF EXISTS hitop_dimensions;
DROP TABLE IF EXISTS reports;
DROP TABLE IF EXISTS transcript_segments;
DROP TABLE IF EXISTS transcripts;
EOF
```

### Task 2.1.4 — Migracja 000010: RAG Memory

```bash
make migrate-create NAME=rag_memory

cat > migrations/000010_rag_memory.up.sql <<'EOF'
-- ============================================
-- RAG MEMORY (per-patient_file context)
-- ============================================
CREATE TABLE rag_memories (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_file_id         UUID NOT NULL REFERENCES patient_files(id) ON DELETE CASCADE,
    source_session_id       UUID REFERENCES sessions(id) ON DELETE SET NULL,
    source_report_id        UUID REFERENCES reports(id) ON DELETE SET NULL,

    -- Encrypted summary chunk (≤ 2000 chars plain text)
    summary_ciphertext      BYTEA NOT NULL,
    summary_encrypted_dek   BYTEA NOT NULL,

    -- Embedding (768 dim from textembedding-gecko or 3072 from text-embedding-005)
    embedding               vector(768) NOT NULL,

    -- Metadata for filtering
    chunk_type              VARCHAR(50) NOT NULL,  -- 'summary', 'theme', 'goal', 'risk'
    importance_score        NUMERIC(4, 3) NOT NULL DEFAULT 0.5,

    -- Compaction support
    is_compacted            BOOLEAN NOT NULL DEFAULT FALSE,
    compacted_into_id       UUID REFERENCES rag_memories(id) ON DELETE SET NULL,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_accessed_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_rag_memories_patient_file ON rag_memories(patient_file_id, created_at DESC) WHERE NOT is_compacted;
-- HNSW index dla similarity search
CREATE INDEX idx_rag_memories_embedding ON rag_memories USING hnsw (embedding vector_cosine_ops);
EOF

cat > migrations/000010_rag_memory.down.sql <<'EOF'
DROP TABLE IF EXISTS rag_memories;
EOF
```

### Task 2.1.5 — Apply migracje

```bash
POSTGRES_PASSWORD=$(gcloud secrets versions access latest --secret=postgres-password --project=superwizor-staging)
CONNECTION_NAME=$(cd infra/environments/staging && terragrunt output -raw sql_connection_name)

./cloud-sql-proxy ${CONNECTION_NAME} --port=5432 &
PROXY_PID=$!
sleep 5

DB_USER=postgres DB_PASSWORD="${POSTGRES_PASSWORD}" make migrate-up

# Sanity check
psql -h 127.0.0.1 -U postgres -d superwizor -c "
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public' ORDER BY table_name;
"

kill ${PROXY_PID}
```

**Spodziewane tabele:** `addresses`, `audio_uploads`, `audit_events`, `hitop_dimensions`, `hitop_measurements`, `modalities`, `organizations`, `patient_files`, `rag_memories`, `reports`, `schema_migrations`, `sessions`, `therapist_patient_relations`, `transcript_segments`, `transcripts`, `users`.

---

## Sprint 2.2 — Cloud Storage + ingestion-svc

**Czas:** 2 dni
**Cel:** Bucket dla audio uploads + ingestion-svc generujący signed URLs.

### Task 2.2.1 — Terraform: Cloud Storage bucket

```bash
mkdir -p infra/modules/audio-storage

cat > infra/modules/audio-storage/main.tf <<'EOF'
variable "project_id" { type = string }
variable "audio_key_id" { type = string }

resource "google_storage_bucket" "audio_uploads" {
  name          = "${var.project_id}-audio-uploads"
  project       = var.project_id
  location      = "EUROPE-CENTRAL2"
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  encryption {
    default_kms_key_name = var.audio_key_id
  }

  versioning {
    enabled = false  # audio files są tymczasowe — wersjonowanie nie ma sensu
  }

  # Object Lifecycle Management — usuń po 48h
  lifecycle_rule {
    condition {
      age = 2  # 2 days
    }
    action {
      type = "Delete"
    }
  }

  # CORS dla Flutter PUT requests
  cors {
    origin          = ["*"]  # ograniczyć w prod do app domain
    method          = ["PUT", "GET", "HEAD"]
    response_header = ["Content-Type", "Content-MD5"]
    max_age_seconds = 3600
  }

  # Audit logging
  logging {
    log_bucket = google_storage_bucket.audio_audit_logs.name
  }
}

resource "google_storage_bucket" "audio_audit_logs" {
  name          = "${var.project_id}-audio-audit-logs"
  project       = var.project_id
  location      = "EUROPE-CENTRAL2"
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  lifecycle_rule {
    condition {
      age = 365
    }
    action {
      type = "Delete"
    }
  }
}

# IAM: pozwól ingestion-svc generować signed URLs
resource "google_service_account" "ingestion_svc" {
  account_id   = "ingestion-svc"
  display_name = "Ingestion Service"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "ingestion_svc_creator" {
  bucket = google_storage_bucket.audio_uploads.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

# IAM: pozwól stt-worker (Cloud Function) czytać
resource "google_service_account" "stt_worker" {
  account_id   = "stt-worker"
  display_name = "STT Worker"
  project      = var.project_id
}

resource "google_storage_bucket_iam_member" "stt_worker_reader" {
  bucket = google_storage_bucket.audio_uploads.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.stt_worker.email}"
}

output "bucket_name" { value = google_storage_bucket.audio_uploads.name }
output "ingestion_svc_email" { value = google_service_account.ingestion_svc.email }
output "stt_worker_email" { value = google_service_account.stt_worker.email }
EOF

# Dodaj do environments/staging/main.tf
cat >> infra/environments/staging/main.tf <<'EOF'

module "audio_storage" {
  source = "../../modules/audio-storage"

  project_id   = var.project_id
  audio_key_id = module.kms.audio_key_id
}

output "audio_bucket_name" { value = module.audio_storage.bucket_name }
EOF

cd infra/environments/staging && terragrunt apply
```

### Task 2.2.2 — Proto definition dla ingestion-svc

```bash
cat > proto/ingestion/v1/ingestion.proto <<'EOF'
syntax = "proto3";

package ingestion.v1;

import "google/protobuf/timestamp.proto";
import "google/protobuf/empty.proto";

option go_package = "github.com/superwizor-ai/backend/gen/go/ingestion/v1;ingestionv1";

service IngestionService {
  // Inicjuje upload — zwraca signed URL i upload ID
  rpc CreateAudioUpload(CreateAudioUploadRequest) returns (CreateAudioUploadResponse);

  // Notyfikuje że upload się zakończył (Flutter wysyła po PUT do GCS)
  rpc CompleteAudioUpload(CompleteAudioUploadRequest) returns (CompleteAudioUploadResponse);

  // Stan uploadu
  rpc GetAudioUploadStatus(GetAudioUploadStatusRequest) returns (AudioUploadStatus);
}

message CreateAudioUploadRequest {
  string therapist_id = 1;
  string patient_file_id = 2;
  string content_type = 3;        // 'audio/m4a'
  int64 estimated_size_bytes = 4;
  int32 estimated_duration_seconds = 5;
  string idempotency_key = 6;
  string client_app_version = 7;
  string client_platform = 8;
}

message CreateAudioUploadResponse {
  string upload_id = 1;
  string signed_url = 2;          // PUT URL z Cloud Storage
  google.protobuf.Timestamp signed_url_expires_at = 3;
  string object_path = 4;
  map<string, string> required_headers = 5;  // x-goog-content-md5, etc.
}

message CompleteAudioUploadRequest {
  string upload_id = 1;
  int32 actual_duration_seconds = 2;
  int64 actual_size_bytes = 3;
  int32 chunk_count = 4;
  string md5_hash = 5;
}

message CompleteAudioUploadResponse {
  string upload_id = 1;
  string session_id = 2;          // utworzona sesja
  bool processing_started = 3;
}

message GetAudioUploadStatusRequest {
  string upload_id = 1;
}

message AudioUploadStatus {
  string upload_id = 1;
  string status = 2;              // PENDING, UPLOADED, PROCESSING, FAILED, EXPIRED
  google.protobuf.Timestamp created_at = 3;
  google.protobuf.Timestamp expires_at = 4;
  string error_message = 5;
}
EOF

make proto
```

### Task 2.2.3 — sqlc + ingestion-svc implementation

```bash
cd services/ingestion-svc

cat > sqlc.yaml <<'EOF'
version: "2"
sql:
  - engine: "postgresql"
    queries: "internal/adapters/postgres/queries"
    schema: "../../migrations"
    gen:
      go:
        package: "db"
        out: "internal/adapters/postgres/db"
        sql_package: "pgx/v5"
        emit_pointers_for_null_types: true
EOF

mkdir -p internal/adapters/postgres/queries

cat > internal/adapters/postgres/queries/audio_uploads.sql <<'EOF'
-- name: CreateAudioUpload :one
INSERT INTO audio_uploads (
    therapist_id, patient_file_id, bucket_name, object_path,
    content_type, idempotency_key, client_app_version, client_platform
) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
RETURNING *;

-- name: GetAudioUploadByIdempotency :one
SELECT * FROM audio_uploads
WHERE idempotency_key = $1 AND therapist_id = $2;

-- name: GetAudioUpload :one
SELECT * FROM audio_uploads WHERE id = $1;

-- name: CompleteAudioUpload :one
UPDATE audio_uploads SET
    status = 'UPLOADED',
    upload_completed_at = now(),
    duration_seconds = $2,
    file_size_bytes = $3,
    chunk_count = $4
WHERE id = $1
RETURNING *;

-- name: MarkAudioUploadFailed :exec
UPDATE audio_uploads SET status = 'FAILED', error_message = $2 WHERE id = $1;
EOF

cat > internal/adapters/postgres/queries/sessions.sql <<'EOF'
-- name: CreateSession :one
INSERT INTO sessions (
    therapist_id, patient_file_id, audio_upload_id,
    session_date, session_number, duration_seconds, contact_form
) VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: GetNextSessionNumber :one
SELECT COALESCE(MAX(session_number), 0) + 1 AS next_number
FROM sessions
WHERE patient_file_id = $1 AND deleted_at IS NULL;
EOF

sqlc generate
```

### Task 2.2.4 — Signed URL generator

```bash
mkdir -p internal/adapters/storage

cat > internal/adapters/storage/signer.go <<'EOF'
package storage

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"cloud.google.com/go/storage"
)

type Signer struct {
	client     *storage.Client
	bucketName string
}

func NewSigner(ctx context.Context, bucketName string) (*Signer, error) {
	client, err := storage.NewClient(ctx)
	if err != nil {
		return nil, fmt.Errorf("create storage client: %w", err)
	}
	return &Signer{client: client, bucketName: bucketName}, nil
}

// GenerateUploadURL creates a V4 signed URL for PUT operation.
// Returns URL valid for 30 minutes.
func (s *Signer) GenerateUploadURL(ctx context.Context, objectPath, contentType string) (string, time.Time, error) {
	expires := time.Now().Add(30 * time.Minute)

	opts := &storage.SignedURLOptions{
		Scheme:      storage.SigningSchemeV4,
		Method:      http.MethodPut,
		Expires:     expires,
		ContentType: contentType,
		Headers: []string{
			"x-goog-meta-source: superwizor-mobile",
		},
	}

	url, err := s.client.Bucket(s.bucketName).SignedURL(objectPath, opts)
	if err != nil {
		return "", time.Time{}, fmt.Errorf("sign URL: %w", err)
	}

	return url, expires, nil
}
EOF
```

### Task 2.2.5 — gRPC server

```bash
mkdir -p internal/adapters/grpc

cat > internal/adapters/grpc/server.go <<'EOF'
package grpc

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
	"google.golang.org/protobuf/types/known/timestamppb"

	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/storage"
)

type Server struct {
	ingestionv1.UnimplementedIngestionServiceServer
	queries    *db.Queries
	signer     *storage.Signer
	bucketName string
	pubsub     PubsubPublisher  // interface — concrete impl w main
}

type PubsubPublisher interface {
	PublishAudioUploaded(ctx context.Context, sessionID, uploadID, objectPath string) error
}

func NewServer(queries *db.Queries, signer *storage.Signer, bucketName string, pubsub PubsubPublisher) *Server {
	return &Server{queries: queries, signer: signer, bucketName: bucketName, pubsub: pubsub}
}

func (s *Server) CreateAudioUpload(ctx context.Context, req *ingestionv1.CreateAudioUploadRequest) (*ingestionv1.CreateAudioUploadResponse, error) {
	therapistID, err := uuid.Parse(req.TherapistId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid therapist_id")
	}
	patientFileID, err := uuid.Parse(req.PatientFileId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid patient_file_id")
	}

	if req.IdempotencyKey == "" {
		return nil, status.Error(codes.InvalidArgument, "idempotency_key required")
	}

	// Idempotency check
	existing, err := s.queries.GetAudioUploadByIdempotency(ctx, db.GetAudioUploadByIdempotencyParams{
		IdempotencyKey: &req.IdempotencyKey,
		TherapistID:    therapistID,
	})
	if err == nil {
		// Already exists — regenerate signed URL
		signedURL, expires, err := s.signer.GenerateUploadURL(ctx, existing.ObjectPath, existing.ContentType)
		if err != nil {
			return nil, status.Error(codes.Internal, err.Error())
		}
		return &ingestionv1.CreateAudioUploadResponse{
			UploadId:           existing.ID.String(),
			SignedUrl:          signedURL,
			SignedUrlExpiresAt: timestamppb.New(expires),
			ObjectPath:         existing.ObjectPath,
		}, nil
	}

	// New upload
	objectPath := fmt.Sprintf("%s/%s/%d.m4a",
		therapistID.String(),
		patientFileID.String(),
		time.Now().Unix(),
	)

	upload, err := s.queries.CreateAudioUpload(ctx, db.CreateAudioUploadParams{
		TherapistID:       therapistID,
		PatientFileID:     patientFileID,
		BucketName:        s.bucketName,
		ObjectPath:        objectPath,
		ContentType:       req.ContentType,
		IdempotencyKey:    &req.IdempotencyKey,
		ClientAppVersion:  &req.ClientAppVersion,
		ClientPlatform:    &req.ClientPlatform,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	signedURL, expires, err := s.signer.GenerateUploadURL(ctx, objectPath, req.ContentType)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return &ingestionv1.CreateAudioUploadResponse{
		UploadId:           upload.ID.String(),
		SignedUrl:          signedURL,
		SignedUrlExpiresAt: timestamppb.New(expires),
		ObjectPath:         objectPath,
	}, nil
}

func (s *Server) CompleteAudioUpload(ctx context.Context, req *ingestionv1.CompleteAudioUploadRequest) (*ingestionv1.CompleteAudioUploadResponse, error) {
	uploadID, err := uuid.Parse(req.UploadId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid upload_id")
	}

	upload, err := s.queries.CompleteAudioUpload(ctx, db.CompleteAudioUploadParams{
		ID:              uploadID,
		DurationSeconds: &req.ActualDurationSeconds,
		FileSizeBytes:   &req.ActualSizeBytes,
		ChunkCount:      req.ChunkCount,
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// Auto-create session
	nextNumber, err := s.queries.GetNextSessionNumber(ctx, upload.PatientFileID)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	session, err := s.queries.CreateSession(ctx, db.CreateSessionParams{
		TherapistID:     upload.TherapistID,
		PatientFileID:   upload.PatientFileID,
		AudioUploadID:   &upload.ID,
		SessionDate:     time.Now(),
		SessionNumber:   int32(nextNumber),
		DurationSeconds: &req.ActualDurationSeconds,
		ContactForm:     "OFFICE",
	})
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// Publish do Pub/Sub → trigger STT worker
	if err := s.pubsub.PublishAudioUploaded(ctx, session.ID.String(), uploadID.String(), upload.ObjectPath); err != nil {
		// Log warning ale nie failuj request — workflow można retry'ować
		// (real impl would log structured)
		fmt.Printf("WARN: failed to publish audio.uploaded: %v\n", err)
	}

	return &ingestionv1.CompleteAudioUploadResponse{
		UploadId:          uploadID.String(),
		SessionId:         session.ID.String(),
		ProcessingStarted: true,
	}, nil
}

func (s *Server) GetAudioUploadStatus(ctx context.Context, req *ingestionv1.GetAudioUploadStatusRequest) (*ingestionv1.AudioUploadStatus, error) {
	id, err := uuid.Parse(req.UploadId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid upload_id")
	}

	upload, err := s.queries.GetAudioUpload(ctx, id)
	if err != nil {
		if errors.Is(err, errNoRows()) {
			return nil, status.Error(codes.NotFound, "upload not found")
		}
		return nil, status.Error(codes.Internal, err.Error())
	}

	resp := &ingestionv1.AudioUploadStatus{
		UploadId:  upload.ID.String(),
		Status:    string(upload.Status),
		CreatedAt: timestamppb.New(upload.CreatedAt),
		ExpiresAt: timestamppb.New(upload.ExpiresAt),
	}
	if upload.ErrorMessage != nil {
		resp.ErrorMessage = *upload.ErrorMessage
	}
	return resp, nil
}

func errNoRows() error {
	// pgx.ErrNoRows alias for testability
	return fmt.Errorf("no rows")
}
EOF
```

### Task 2.2.6 — Pub/Sub publisher

```bash
mkdir -p internal/adapters/pubsub

cat > internal/adapters/pubsub/publisher.go <<'EOF'
package pubsub

import (
	"context"
	"encoding/json"
	"fmt"

	"cloud.google.com/go/pubsub"
)

type Publisher struct {
	client *pubsub.Client
}

func NewPublisher(ctx context.Context, projectID string) (*Publisher, error) {
	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		return nil, fmt.Errorf("pubsub client: %w", err)
	}
	return &Publisher{client: client}, nil
}

type AudioUploadedEvent struct {
	SessionID  string `json:"session_id"`
	UploadID   string `json:"upload_id"`
	ObjectPath string `json:"object_path"`
}

func (p *Publisher) PublishAudioUploaded(ctx context.Context, sessionID, uploadID, objectPath string) error {
	payload := AudioUploadedEvent{
		SessionID:  sessionID,
		UploadID:   uploadID,
		ObjectPath: objectPath,
	}
	data, err := json.Marshal(payload)
	if err != nil {
		return err
	}

	topic := p.client.Topic("audio.uploaded")
	defer topic.Stop()

	res := topic.Publish(ctx, &pubsub.Message{
		Data: data,
		Attributes: map[string]string{
			"event_type": "audio.uploaded",
			"session_id": sessionID,
		},
	})
	_, err = res.Get(ctx)
	return err
}
EOF
```

### Task 2.2.7 — main.go + Dockerfile + deploy

```bash
cat > cmd/server/main.go <<'EOF'
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	ingestionv1 "github.com/superwizor-ai/backend/gen/go/ingestion/v1"
	grpcadapter "github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/grpc"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/postgres/db"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/pubsub"
	"github.com/superwizor-ai/backend/services/ingestion-svc/internal/adapters/storage"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	ctx := context.Background()

	port := getenv("PORT", "8080")
	projectID := os.Getenv("GCP_PROJECT_ID")
	bucketName := os.Getenv("AUDIO_BUCKET_NAME")
	dbDSN := os.Getenv("DATABASE_URL")

	if projectID == "" || bucketName == "" || dbDSN == "" {
		slog.Error("required env missing")
		os.Exit(1)
	}

	pool, err := pgxpool.New(ctx, dbDSN)
	if err != nil {
		slog.Error("db", "error", err)
		os.Exit(1)
	}
	defer pool.Close()

	signer, err := storage.NewSigner(ctx, bucketName)
	if err != nil {
		slog.Error("signer", "error", err)
		os.Exit(1)
	}

	publisher, err := pubsub.NewPublisher(ctx, projectID)
	if err != nil {
		slog.Error("pubsub", "error", err)
		os.Exit(1)
	}

	queries := db.New(pool)
	srv := grpcadapter.NewServer(queries, signer, bucketName, publisher)

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("listen", "error", err)
		os.Exit(1)
	}

	gs := grpc.NewServer()
	ingestionv1.RegisterIngestionServiceServer(gs, srv)

	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	slog.Info("ingestion-svc starting", "port", port)
	if err := gs.Serve(lis); err != nil {
		slog.Error("serve", "error", err)
		os.Exit(1)
	}
}

func getenv(k, d string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return d
}
EOF

# Dockerfile (analogiczny do identity-svc)
cat > Dockerfile <<'EOF'
FROM golang:1.23-alpine AS builder
WORKDIR /app
COPY go.work go.work.sum ./
COPY services/ingestion-svc services/ingestion-svc
COPY pkg/ pkg/
COPY gen/ gen/
WORKDIR /app/services/ingestion-svc
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o /server ./cmd/server

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=builder /server /server
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/server"]
EOF

# Deploy
cd ../..
gcloud builds submit \
  --tag europe-central2-docker.pkg.dev/superwizor-staging/services/ingestion-svc:v0.1.0 \
  --project=superwizor-staging \
  -f services/ingestion-svc/Dockerfile

BUCKET_NAME=$(cd infra/environments/staging && terragrunt output -raw audio_bucket_name)

gcloud run deploy ingestion-svc \
  --image=europe-central2-docker.pkg.dev/superwizor-staging/services/ingestion-svc:v0.1.0 \
  --region=europe-central2 \
  --project=superwizor-staging \
  --service-account=ingestion-svc@superwizor-staging.iam.gserviceaccount.com \
  --no-allow-unauthenticated \
  --vpc-connector=swvpc-connector \
  --use-http2 \
  --set-env-vars="GCP_PROJECT_ID=superwizor-staging,AUDIO_BUCKET_NAME=${BUCKET_NAME}" \
  --set-secrets="DATABASE_URL=postgres-database-url:latest"
```

### Smoke test Sprint 2.2

```bash
TOKEN=$(gcloud auth print-identity-token)
URL=$(gcloud run services describe ingestion-svc --region=europe-central2 --project=superwizor-staging --format="value(status.url)" | sed 's|https://||')

# Test signed URL generation
grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d '{
    "therapist_id": "TYPE_VALID_UUID",
    "patient_file_id": "TYPE_VALID_UUID",
    "content_type": "audio/m4a",
    "estimated_duration_seconds": 1800,
    "idempotency_key": "test-1"
  }' \
  ${URL}:443 ingestion.v1.IngestionService/CreateAudioUpload
```

---

## Sprint 2.3 — billing-svc (stub)

**Czas:** 1 dzień
**Cel:** Mock billing-svc zwracający zawsze `allowed=true`. Pełna logika Stripe w Fazie 3.

### Task 2.3.1 — Proto

```bash
cat > proto/billing/v1/billing.proto <<'EOF'
syntax = "proto3";

package billing.v1;

import "google/protobuf/empty.proto";

option go_package = "github.com/superwizor-ai/backend/gen/go/billing/v1;billingv1";

service BillingService {
  // Sprawdza czy organizacja ma quotę na nową sesję
  rpc CheckQuota(CheckQuotaRequest) returns (QuotaDecision);

  // Inkrementuje usage po zakończonej analizie
  rpc IncrementUsage(IncrementUsageRequest) returns (google.protobuf.Empty);

  // Stan subskrypcji
  rpc GetSubscription(GetSubscriptionRequest) returns (Subscription);
}

message CheckQuotaRequest {
  string organization_id = 1;
  string therapist_id = 2;
  string usage_type = 3;          // 'session_analysis', 'audio_minutes'
  int32 amount = 4;
}

message QuotaDecision {
  bool allowed = 1;
  string reason = 2;
  int32 remaining = 3;
  int32 limit = 4;
}

message IncrementUsageRequest {
  string organization_id = 1;
  string therapist_id = 2;
  string usage_type = 3;
  int32 amount = 4;
  string session_id = 5;          // dla audit
  string idempotency_key = 6;
}

message GetSubscriptionRequest {
  string organization_id = 1;
}

message Subscription {
  string id = 1;
  string plan_tier = 2;            // 'SOLO', 'PRO', 'CLINIC'
  string status = 3;
  int32 sessions_per_month_limit = 4;
  int32 sessions_used_this_period = 5;
}
EOF

make proto
```

### Task 2.3.2 — Stub implementation

```bash
cd services/billing-svc

mkdir -p internal/adapters/grpc cmd/server

cat > internal/adapters/grpc/server.go <<'EOF'
package grpc

import (
	"context"

	"google.golang.org/protobuf/types/known/emptypb"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
)

// Server is a STUB implementation. Always returns "allowed" for any quota check.
// Replaced with full Stripe integration in Faza 3.
type Server struct {
	billingv1.UnimplementedBillingServiceServer
	version string
}

func NewServer(version string) *Server {
	return &Server{version: version}
}

func (s *Server) CheckQuota(ctx context.Context, req *billingv1.CheckQuotaRequest) (*billingv1.QuotaDecision, error) {
	return &billingv1.QuotaDecision{
		Allowed:   true,
		Reason:    "stub: always allowed in Faza 2",
		Remaining: 999,
		Limit:     1000,
	}, nil
}

func (s *Server) IncrementUsage(ctx context.Context, req *billingv1.IncrementUsageRequest) (*emptypb.Empty, error) {
	// No-op in stub. Faza 3 będzie zapisywać do usage_quotas table.
	return &emptypb.Empty{}, nil
}

func (s *Server) GetSubscription(ctx context.Context, req *billingv1.GetSubscriptionRequest) (*billingv1.Subscription, error) {
	return &billingv1.Subscription{
		Id:                       "stub-subscription",
		PlanTier:                 "PRO",
		Status:                   "ACTIVE",
		SessionsPerMonthLimit:    1000,
		SessionsUsedThisPeriod:   0,
	}, nil
}
EOF

cat > cmd/server/main.go <<'EOF'
package main

import (
	"fmt"
	"log/slog"
	"net"
	"os"

	"google.golang.org/grpc"
	"google.golang.org/grpc/health"
	healthpb "google.golang.org/grpc/health/grpc_health_v1"
	"google.golang.org/grpc/reflection"

	billingv1 "github.com/superwizor-ai/backend/gen/go/billing/v1"
	grpcadapter "github.com/superwizor-ai/backend/services/billing-svc/internal/adapters/grpc"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	lis, err := net.Listen("tcp", fmt.Sprintf(":%s", port))
	if err != nil {
		slog.Error("listen", "error", err)
		os.Exit(1)
	}

	gs := grpc.NewServer()
	billingv1.RegisterBillingServiceServer(gs, grpcadapter.NewServer("v0.1.0-stub"))

	hs := health.NewServer()
	hs.SetServingStatus("", healthpb.HealthCheckResponse_SERVING)
	healthpb.RegisterHealthServer(gs, hs)
	reflection.Register(gs)

	slog.Info("billing-svc (STUB) starting", "port", port)
	if err := gs.Serve(lis); err != nil {
		slog.Error("serve", "error", err)
		os.Exit(1)
	}
}
EOF

# Dockerfile + deploy (analogicznie)
```

---

## Sprint 2.4 — Pub/Sub

**Czas:** 1 dzień

### Task 2.4.1 — Pub/Sub topics + subscriptions z DLQ

```bash
mkdir -p infra/modules/pubsub

cat > infra/modules/pubsub/main.tf <<'EOF'
variable "project_id" { type = string }

# ============================================
# TOPICS
# ============================================
resource "google_pubsub_topic" "audio_uploaded" {
  name    = "audio.uploaded"
  project = var.project_id
}

resource "google_pubsub_topic" "transcript_completed" {
  name    = "transcript.completed"
  project = var.project_id
}

resource "google_pubsub_topic" "report_generated" {
  name    = "report.generated"
  project = var.project_id
}

# DLQ topics
resource "google_pubsub_topic" "audio_uploaded_dlq" {
  name    = "audio.uploaded.dlq"
  project = var.project_id
}

resource "google_pubsub_topic" "transcript_completed_dlq" {
  name    = "transcript.completed.dlq"
  project = var.project_id
}

# ============================================
# SUBSCRIPTIONS — Eventarc/CloudFunctions używają własnych
# (te są dla manual debugging i other consumers)
# ============================================
resource "google_pubsub_subscription" "audio_uploaded_debug" {
  name    = "audio.uploaded.debug"
  project = var.project_id
  topic   = google_pubsub_topic.audio_uploaded.id

  ack_deadline_seconds = 60
  message_retention_duration = "604800s"  # 7 days

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.audio_uploaded_dlq.id
    max_delivery_attempts = 5
  }
}

# IAM: ingestion-svc może publishować
resource "google_pubsub_topic_iam_member" "ingestion_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.audio_uploaded.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:ingestion-svc@${var.project_id}.iam.gserviceaccount.com"
}

# IAM: stt-worker może publishować transcript.completed
resource "google_pubsub_topic_iam_member" "stt_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.transcript_completed.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:stt-worker@${var.project_id}.iam.gserviceaccount.com"
}

output "audio_uploaded_topic" { value = google_pubsub_topic.audio_uploaded.id }
output "transcript_completed_topic" { value = google_pubsub_topic.transcript_completed.id }
output "report_generated_topic" { value = google_pubsub_topic.report_generated.id }
EOF

cat >> infra/environments/staging/main.tf <<'EOF'

module "pubsub" {
  source     = "../../modules/pubsub"
  project_id = var.project_id
}
EOF

cd infra/environments/staging && terragrunt apply
```

---

## Sprint 2.5 — STT worker

**Czas:** 2 dni
**Cel:** Cloud Function Gen2 reagująca na `audio.uploaded`, używająca Chirp 3 z diarization. **Generuje neutralne lokalizowane speaker labels** (zob. ADR-IMPL-002), NIE rozpoznaje ról.

### Task 2.5.0 — Pakiet pkg/i18n/speakerlabels

```bash
mkdir -p pkg/i18n/speakerlabels

cat > pkg/i18n/speakerlabels/labels.go <<'EOF'
// Package speakerlabels generuje lokalizowane neutralne etykiety dla mówców
// w transkrypcji. Używane gdy diarization zwraca speaker_tag=1,2,3...
// a my potrzebujemy ludzkiej etykiety w języku rozmowy.
//
// Etykiety są neutralne — NIE oznaczają ról (terapeuta/pacjent).
// Role są dedukowane przez LLM podczas analizy raportu.
package speakerlabels

import (
	"fmt"
	"strings"
)

// templates mapuje BCP-47 language tags (lub language prefix) na sformatowany
// pattern dla speaker label. Pattern zawiera "%d" dla numeru speakera.
//
// Klucz: pełny tag (np. "en-US") lub sam język (np. "en") — pełny tag ma priorytet.
// Wartość: format string z %d.
var templates = map[string]string{
	// Polski + slavic
	"pl":    "Osoba %d",
	"cs":    "Osoba %d",
	"sk":    "Osoba %d",
	"ru":    "Человек %d",
	"uk":    "Особа %d",
	"bg":    "Лице %d",
	"sr":    "Особа %d",
	"hr":    "Osoba %d",
	"sl":    "Oseba %d",

	// English
	"en":    "Person %d",

	// Romance
	"es":    "Persona %d",
	"pt":    "Pessoa %d",
	"fr":    "Personne %d",
	"it":    "Persona %d",
	"ro":    "Persoana %d",
	"ca":    "Persona %d",

	// Germanic
	"de":    "Person %d",
	"nl":    "Persoon %d",
	"sv":    "Person %d",
	"no":    "Person %d",
	"nb":    "Person %d",
	"da":    "Person %d",
	"fi":    "Henkilö %d",
	"is":    "Manneskja %d",

	// Hungarian / Estonian / Latvian / Lithuanian
	"hu":    "Személy %d",
	"et":    "Isik %d",
	"lv":    "Persona %d",
	"lt":    "Asmuo %d",

	// Greek
	"el":    "Άτομο %d",

	// Turkish
	"tr":    "Kişi %d",

	// Arabic
	"ar":    "متحدث %d",

	// Hebrew
	"he":    "דובר %d",
	"iw":    "דובר %d",  // legacy code

	// Persian
	"fa":    "گوینده %d",

	// Indic
	"hi":    "व्यक्ति %d",
	"bn":    "ব্যক্তি %d",
	"ta":    "நபர் %d",
	"te":    "వ్యక్తి %d",
	"mr":    "व्यक्ती %d",
	"gu":    "વ્યક્તિ %d",
	"kn":    "ವ್ಯಕ್ತಿ %d",
	"ml":    "വ്യക്തി %d",
	"pa":    "ਵਿਅਕਤੀ %d",
	"ur":    "شخص %d",

	// East Asian
	"ja":    "話者%d",
	"ko":    "화자 %d",
	"cmn":   "说话人 %d",
	"zh":    "说话人 %d",
	"yue":   "說話人 %d",

	// Southeast Asian
	"vi":    "Người %d",
	"th":    "ผู้พูด %d",
	"id":    "Orang %d",
	"ms":    "Orang %d",
	"fil":   "Tao %d",
	"tl":    "Tao %d",

	// African
	"sw":    "Mtu %d",
	"af":    "Persoon %d",
	"am":    "ሰው %d",

	// Caucasian / others
	"ka":    "ადამიანი %d",
	"hy":    "Անձ %d",
	"az":    "Şəxs %d",
	"kk":    "Адам %d",
	"uz":    "Shaxs %d",
}

// Generate zwraca lokalizowaną etykietę dla mówcy o danym tagu (1, 2, 3...).
// Jeśli locale jest nieznany, używa fallback "Speaker %d" (English).
//
// languageCode może być w formacie BCP-47: "pl-PL", "en-US", "cmn-CN",
// albo samego języka: "pl", "en", "cmn". Funkcja akceptuje oba.
func Generate(languageCode string, speakerTag int) string {
	pattern := lookupTemplate(languageCode)
	return fmt.Sprintf(pattern, speakerTag)
}

// GenerateMapping tworzy słownik {speaker_tag → label} dla podanego zbioru tagów.
// Wynik jest deterministycznie posortowany po tagu (1, 2, 3...).
func GenerateMapping(languageCode string, speakerTags []int) map[int]string {
	mapping := make(map[int]string, len(speakerTags))
	for _, tag := range speakerTags {
		mapping[tag] = Generate(languageCode, tag)
	}
	return mapping
}

// lookupTemplate znajduje pattern dla locale.
// Strategia: pełen tag → język → fallback English.
func lookupTemplate(languageCode string) string {
	if languageCode == "" {
		return "Speaker %d"
	}

	// 1. Pełny tag
	if pattern, ok := templates[languageCode]; ok {
		return pattern
	}

	// 2. Sam język (przed myślnikiem)
	if idx := strings.IndexAny(languageCode, "-_"); idx > 0 {
		lang := strings.ToLower(languageCode[:idx])
		if pattern, ok := templates[lang]; ok {
			return pattern
		}
	}

	// 3. Może już jest sam język (lowercase)
	if pattern, ok := templates[strings.ToLower(languageCode)]; ok {
		return pattern
	}

	// 4. Fallback English
	return "Speaker %d"
}
EOF
```

### Task 2.5.0b — Test pakietu

```bash
cat > pkg/i18n/speakerlabels/labels_test.go <<'EOF'
package speakerlabels

import "testing"

func TestGenerate(t *testing.T) {
	tests := []struct {
		locale   string
		tag      int
		expected string
	}{
		{"pl-PL", 1, "Osoba 1"},
		{"pl", 2, "Osoba 2"},
		{"en-US", 1, "Person 1"},
		{"en-GB", 3, "Person 3"},
		{"de-DE", 1, "Person 1"},
		{"fr-FR", 2, "Personne 2"},
		{"es-ES", 1, "Persona 1"},
		{"ja-JP", 1, "話者1"},
		{"ko-KR", 2, "화자 2"},
		{"cmn-CN", 1, "说话人 1"},
		{"ar-XA", 1, "متحدث 1"},
		// Fallback
		{"klingon-Q1", 1, "Speaker 1"},
		{"", 1, "Speaker 1"},
		{"unknown", 5, "Speaker 5"},
	}

	for _, tt := range tests {
		t.Run(tt.locale, func(t *testing.T) {
			got := Generate(tt.locale, tt.tag)
			if got != tt.expected {
				t.Errorf("Generate(%q, %d) = %q, want %q", tt.locale, tt.tag, got, tt.expected)
			}
		})
	}
}

func TestGenerateMapping(t *testing.T) {
	mapping := GenerateMapping("pl-PL", []int{1, 2, 3})

	if len(mapping) != 3 {
		t.Fatalf("expected 3 entries, got %d", len(mapping))
	}
	if mapping[1] != "Osoba 1" {
		t.Errorf("mapping[1] = %q, want 'Osoba 1'", mapping[1])
	}
	if mapping[2] != "Osoba 2" {
		t.Errorf("mapping[2] = %q, want 'Osoba 2'", mapping[2])
	}
}
EOF

cd pkg/i18n/speakerlabels
go test -v
```



### Task 2.5.1 — Service Account + IAM dla Vertex AI Speech

```bash
# Pozwól stt-worker wywoływać Speech-to-Text (cross-region: europe-west4)
gcloud projects add-iam-policy-binding superwizor-staging \
  --member="serviceAccount:stt-worker@superwizor-staging.iam.gserviceaccount.com" \
  --role="roles/speech.user"

# Cloud SQL access
gcloud projects add-iam-policy-binding superwizor-staging \
  --member="serviceAccount:stt-worker@superwizor-staging.iam.gserviceaccount.com" \
  --role="roles/cloudsql.client"
```

### Task 2.5.2 — STT worker code

```bash
cd services/ai-pipeline-svc/cmd/stt-worker

cat > main.go <<'EOF'
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"sort"
	"time"

	"cloud.google.com/go/pubsub"
	speech "cloud.google.com/go/speech/apiv2"
	"cloud.google.com/go/speech/apiv2/speechpb"
	"github.com/GoogleCloudPlatform/functions-framework-go/funcframework"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/superwizor-ai/backend/pkg/i18n/speakerlabels"
)

// AudioUploadedEvent matches publisher payload
type AudioUploadedEvent struct {
	SessionID  string `json:"session_id"`
	UploadID   string `json:"upload_id"`
	ObjectPath string `json:"object_path"`
}

// PubSubMessage from Eventarc trigger
type PubSubMessage struct {
	Data       []byte            `json:"data"`
	Attributes map[string]string `json:"attributes"`
}

type Event struct {
	Message PubSubMessage `json:"message"`
}

var (
	dbPool      *pgxpool.Pool
	speechClient *speech.Client
	pubsubClient *pubsub.Client
	bucketName   string
	projectID    string
)

func init() {
	ctx := context.Background()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	projectID = os.Getenv("GCP_PROJECT_ID")
	bucketName = os.Getenv("AUDIO_BUCKET_NAME")
	dbDSN := os.Getenv("DATABASE_URL")

	var err error
	dbPool, err = pgxpool.New(ctx, dbDSN)
	if err != nil {
		slog.Error("db init", "error", err)
		os.Exit(1)
	}

	// Speech client w europe-west4 (Chirp 3 dostępne)
	speechClient, err = speech.NewClient(ctx,
		// option.WithEndpoint("europe-west4-speech.googleapis.com:443"),
	)
	if err != nil {
		slog.Error("speech client", "error", err)
		os.Exit(1)
	}

	pubsubClient, err = pubsub.NewClient(ctx, projectID)
	if err != nil {
		slog.Error("pubsub client", "error", err)
		os.Exit(1)
	}

	funcframework.RegisterEventFunctionContext(ctx, "/", processAudio)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if err := funcframework.Start(port); err != nil {
		slog.Error("framework start", "error", err)
		os.Exit(1)
	}
}

func processAudio(ctx context.Context, e Event) error {
	logger := slog.With("function", "stt-worker")

	var event AudioUploadedEvent
	if err := json.Unmarshal(e.Message.Data, &event); err != nil {
		// Try base64 decode (Pub/Sub envelope)
		decoded, dErr := base64.StdEncoding.DecodeString(string(e.Message.Data))
		if dErr != nil {
			logger.Error("decode payload", "error", err)
			return err
		}
		if err := json.Unmarshal(decoded, &event); err != nil {
			return err
		}
	}

	logger = logger.With("session_id", event.SessionID, "upload_id", event.UploadID)
	logger.Info("processing audio")

	startTime := time.Now()

	// 1. Update session status
	if err := updateSessionStatus(ctx, event.SessionID, "TRANSCRIBING"); err != nil {
		logger.Error("status update", "error", err)
		return err
	}

	// 2. Run Chirp 3 batch recognize
	gcsURI := fmt.Sprintf("gs://%s/%s", bucketName, event.ObjectPath)
	transcriptResult, err := transcribeWithDiarization(ctx, gcsURI)
	if err != nil {
		logger.Error("chirp 3", "error", err)
		_ = updateSessionStatus(ctx, event.SessionID, "FAILED")
		return err
	}

	// 3. Generuj neutralne lokalizowane labels (NIE role)
	//    Pełne uzasadnienie: ADR-IMPL-002. Role są dedukowane przez LLM w Sprint 2.6.
	speakerLabels := generateSpeakerLabels(transcriptResult.Segments, transcriptResult.LanguageCode)

	// 4. Persist blob (kanoniczny, ADR-IMPL-006) + segments (statystyki)
	transcriptID, err := persistTranscript(ctx, event.SessionID, transcriptResult, speakerLabels, time.Since(startTime))
	if err != nil {
		logger.Error("persist", "error", err)
		_ = updateSessionStatus(ctx, event.SessionID, "FAILED")
		return err
	}

	// 5. Update session: zapisz mapping labels + language_code
	if err := updateSessionLabels(ctx, event.SessionID, speakerLabels, transcriptResult.LanguageCode); err != nil {
		logger.Warn("session labels update", "error", err)
	}
	_ = updateSessionStatus(ctx, event.SessionID, "ANALYZING")

	// 6. Publish transcript.completed
	if err := publishTranscriptCompleted(ctx, event.SessionID, transcriptID); err != nil {
		logger.Error("publish completed", "error", err)
		return err
	}

	logger.Info("done",
		"transcript_id", transcriptID,
		"duration_ms", time.Since(startTime).Milliseconds(),
		"segments", len(transcriptResult.Segments))

	return nil
}

type TranscriptResult struct {
	Segments       []TranscriptSegment
	LanguageCode   string
	WordCount      int
	SpeakerCount   int
	ConfidenceAvg  float32
}

type TranscriptSegment struct {
	SpeakerTag    int32
	StartOffsetMS int64
	EndOffsetMS   int64
	Text          string
	WordCount     int
	Confidence    float32
}

func transcribeWithDiarization(ctx context.Context, gcsURI string) (*TranscriptResult, error) {
	req := &speechpb.BatchRecognizeRequest{
		Recognizer: fmt.Sprintf("projects/%s/locations/europe-west4/recognizers/_", projectID),
		Config: &speechpb.RecognitionConfig{
			DecodingConfig: &speechpb.RecognitionConfig_AutoDecodingConfig{
				AutoDecodingConfig: &speechpb.AutoDetectDecodingConfig{},
			},
			Model:         "chirp_3",
			LanguageCodes: []string{"pl-PL"},
			Features: &speechpb.RecognitionFeatures{
				EnableAutomaticPunctuation: true,
				EnableWordTimeOffsets:      true,
				DiarizationConfig: &speechpb.SpeakerDiarizationConfig{
					MinSpeakerCount: 2,
					MaxSpeakerCount: 4,
				},
			},
		},
		Files: []*speechpb.BatchRecognizeFileMetadata{
			{
				AudioSource: &speechpb.BatchRecognizeFileMetadata_Uri{Uri: gcsURI},
			},
		},
		RecognitionOutputConfig: &speechpb.RecognitionOutputConfig{
			Output: &speechpb.RecognitionOutputConfig_InlineResponseConfig{
				InlineResponseConfig: &speechpb.InlineOutputConfig{},
			},
		},
	}

	op, err := speechClient.BatchRecognize(ctx, req)
	if err != nil {
		return nil, fmt.Errorf("batch recognize: %w", err)
	}

	resp, err := op.Wait(ctx)
	if err != nil {
		return nil, fmt.Errorf("await: %w", err)
	}

	result := &TranscriptResult{LanguageCode: "pl-PL"}
	speakerSet := make(map[int32]bool)
	totalConfidence := float32(0)
	confidenceCount := 0

	for _, fileResult := range resp.Results {
		if fileResult.Transcript == nil {
			continue
		}
		for _, r := range fileResult.Transcript.Results {
			if len(r.Alternatives) == 0 {
				continue
			}
			alt := r.Alternatives[0]

			// Build segments per speaker turn
			currentSegment := TranscriptSegment{}
			for _, w := range alt.Words {
				speakerTag := w.SpeakerLabel
				speakerSet[parseSpeakerLabel(speakerTag)] = true

				wordOffset := w.StartOffset.AsDuration().Milliseconds()
				wordEndOffset := w.EndOffset.AsDuration().Milliseconds()

				if currentSegment.SpeakerTag != parseSpeakerLabel(speakerTag) {
					if currentSegment.Text != "" {
						result.Segments = append(result.Segments, currentSegment)
					}
					currentSegment = TranscriptSegment{
						SpeakerTag:    parseSpeakerLabel(speakerTag),
						StartOffsetMS: wordOffset,
						EndOffsetMS:   wordEndOffset,
					}
				}
				currentSegment.Text += w.Word + " "
				currentSegment.EndOffsetMS = wordEndOffset
				currentSegment.WordCount++
				result.WordCount++
			}
			if currentSegment.Text != "" {
				result.Segments = append(result.Segments, currentSegment)
			}

			if alt.Confidence > 0 {
				totalConfidence += alt.Confidence
				confidenceCount++
			}
		}
	}

	if confidenceCount > 0 {
		result.ConfidenceAvg = totalConfidence / float32(confidenceCount)
	}
	result.SpeakerCount = len(speakerSet)

	return result, nil
}

func parseSpeakerLabel(label string) int32 {
	// "speaker_1" → 1
	var n int32
	fmt.Sscanf(label, "speaker_%d", &n)
	return n
}

// generateSpeakerLabels tworzy mapping speaker_tag → lokalizowana etykieta.
// NIE zwraca ról (THERAPIST/PATIENT) — to robi LLM w Sprint 2.6.
//
// Dla pl-PL: {1: "Osoba 1", 2: "Osoba 2", 3: "Osoba 3"}
// Dla en-US: {1: "Person 1", 2: "Person 2"}
// Dla unknown locale: {1: "Speaker 1", 2: "Speaker 2"}
func generateSpeakerLabels(segments []TranscriptSegment, languageCode string) map[int32]string {
	if len(segments) == 0 {
		return map[int32]string{}
	}

	// Zbierz wszystkie unique speaker tags
	speakerTagsSet := map[int32]bool{}
	for _, seg := range segments {
		speakerTagsSet[seg.SpeakerTag] = true
	}

	// Zamień na sorted slice (deterministyczne kolejność)
	tags := make([]int32, 0, len(speakerTagsSet))
	for t := range speakerTagsSet {
		tags = append(tags, t)
	}
	sort.Slice(tags, func(i, j int) bool { return tags[i] < tags[j] })

	// Generuj labels per tag
	mapping := make(map[int32]string, len(tags))
	for _, tag := range tags {
		mapping[tag] = speakerlabels.Generate(languageCode, int(tag))
	}

	return mapping
}

// Helpers SQL — uproszczone, w prod używamy sqlc-generated code
func updateSessionStatus(ctx context.Context, sessionID, status string) error {
	id, err := uuid.Parse(sessionID)
	if err != nil {
		return err
	}
	_, err = dbPool.Exec(ctx,
		"UPDATE sessions SET status = $1, status_updated_at = now() WHERE id = $2",
		status, id)
	return err
}

func updateSessionLabels(ctx context.Context, sessionID string, mapping map[int32]string, languageCode string) error {
	id, _ := uuid.Parse(sessionID)

	// Konwertuj klucze int32 → string dla JSONB
	jsonMapping := make(map[string]string, len(mapping))
	for tag, label := range mapping {
		jsonMapping[fmt.Sprintf("%d", tag)] = label
	}
	jsonBytes, _ := json.Marshal(jsonMapping)

	_, err := dbPool.Exec(ctx, `
		UPDATE sessions
		SET speaker_label_mapping = $1, language_code = $2
		WHERE id = $3`,
		jsonBytes, languageCode, id)
	return err
}

// persistTranscript zapisuje:
// 1. KANONICZNY blob w `transcripts.transcript_ciphertext` — JSON z full text + labels.
// 2. Segmenty w `transcript_segments` jako per-speaker statystyki + źródło rebuild.
//
// Zob. ADR-IMPL-006 — blob jest source of truth, Flutter czyta tylko z `transcripts`.
func persistTranscript(ctx context.Context, sessionID string, result *TranscriptResult, labels map[int32]string, processingTime time.Duration) (string, error) {
	transcriptID := uuid.New()
	sessID, _ := uuid.Parse(sessionID)

	// Build kanoniczny blob — pełny tekst z labels
	type BlobLine struct {
		SpeakerTag   int32  `json:"speaker_tag"`
		SpeakerLabel string `json:"speaker_label"`
		Text         string `json:"text"`
		StartMS      int64  `json:"start_ms"`
		EndMS        int64  `json:"end_ms"`
		Confidence   float32 `json:"confidence"`
	}

	blobLines := make([]BlobLine, 0, len(result.Segments))
	for _, seg := range result.Segments {
		label := labels[seg.SpeakerTag]
		if label == "" {
			label = fmt.Sprintf("Speaker %d", seg.SpeakerTag)  // safety fallback
		}
		blobLines = append(blobLines, BlobLine{
			SpeakerTag:   seg.SpeakerTag,
			SpeakerLabel: label,
			Text:         strings.TrimSpace(seg.Text),
			StartMS:      seg.StartOffsetMS,
			EndMS:        seg.EndOffsetMS,
			Confidence:   seg.Confidence,
		})
	}

	blobJSON, _ := json.Marshal(blobLines)

	// PRODUCTION: użyj envelope encryption (Cloud KMS).
	// Faza 2 — placeholder bytes (do zastąpienia w hardening Faza 3).
	blobCiphertext := []byte("ENCRYPT_PLACEHOLDER:" + string(blobJSON))
	blobDEK := []byte("DEK_PLACEHOLDER")

	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	// 1. INSERT transcripts (kanoniczny blob)
	_, err = tx.Exec(ctx, `
		INSERT INTO transcripts (
			id, session_id, transcript_ciphertext, transcript_encrypted_dek,
			language_code, word_count, speaker_count, confidence_avg,
			stt_model, stt_processing_seconds
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
		transcriptID, sessID, blobCiphertext, blobDEK,
		result.LanguageCode, result.WordCount, result.SpeakerCount,
		result.ConfidenceAvg, "chirp_3", int(processingTime.Seconds()))
	if err != nil {
		return "", err
	}

	// 2. INSERT transcript_segments (statystyki + rebuild source)
	for _, seg := range result.Segments {
		segID := uuid.New()
		segText := strings.TrimSpace(seg.Text)

		// Per-segment encryption (zachowane dla granularnego access pattern w przyszłości)
		segCiphertext := []byte("ENCRYPT_PLACEHOLDER:" + segText)
		segDEK := []byte("DEK_PLACEHOLDER")

		label := labels[seg.SpeakerTag]
		if label == "" {
			label = fmt.Sprintf("Speaker %d", seg.SpeakerTag)
		}

		_, err = tx.Exec(ctx, `
			INSERT INTO transcript_segments (
				id, transcript_id, speaker_tag, speaker_label,
				start_offset_ms, end_offset_ms,
				text_ciphertext, text_encrypted_dek,
				text_word_count, confidence
			) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)`,
			segID, transcriptID, seg.SpeakerTag, label,
			seg.StartOffsetMS, seg.EndOffsetMS,
			segCiphertext, segDEK,
			seg.WordCount, seg.Confidence)
		if err != nil {
			return "", err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}

	return transcriptID.String(), nil
}

func publishTranscriptCompleted(ctx context.Context, sessionID, transcriptID string) error {
	topic := pubsubClient.Topic("transcript.completed")
	defer topic.Stop()

	payload, _ := json.Marshal(map[string]string{
		"session_id":    sessionID,
		"transcript_id": transcriptID,
	})

	res := topic.Publish(ctx, &pubsub.Message{
		Data: payload,
		Attributes: map[string]string{
			"event_type": "transcript.completed",
			"session_id": sessionID,
		},
	})
	_, err := res.Get(ctx)
	return err
}

// Defensywny stub — w prod struct nie jest używany jak http.Handler
var _ = http.HandlerFunc(nil)
EOF
```

### Task 2.5.3 — Deploy Cloud Function Gen2

```bash
gcloud functions deploy stt-worker \
  --gen2 \
  --runtime=go122 \
  --region=europe-central2 \
  --project=superwizor-staging \
  --source=services/ai-pipeline-svc/cmd/stt-worker \
  --entry-point=cloudevent \
  --trigger-topic=audio.uploaded \
  --service-account=stt-worker@superwizor-staging.iam.gserviceaccount.com \
  --vpc-connector=swvpc-connector \
  --memory=1Gi \
  --cpu=1 \
  --timeout=540s \
  --max-instances=10 \
  --concurrency=1 \
  --set-env-vars="GCP_PROJECT_ID=superwizor-staging,AUDIO_BUCKET_NAME=superwizor-staging-audio-uploads" \
  --set-secrets="DATABASE_URL=postgres-database-url:latest"
```

---

## Sprint 2.6 — LLM worker

**Czas:** 3 dni
**Cel:** Cloud Function Gen2 reagująca na `transcript.completed`. Pełen pipeline: load RAG → Gemini 2.5 PRO → HiTOP extraction → save report → write embeddings.

### Task 2.6.1 — JSON Schema dla Gemini structured output

```bash
mkdir -p services/ai-pipeline-svc/internal/llm/schemas

cat > services/ai-pipeline-svc/internal/llm/schemas/report_schema.json <<'EOF'
{
  "type": "object",
  "properties": {
    "title": {
      "type": "string",
      "description": "Krótki, opisowy tytuł raportu (max 100 znaków)"
    },
    "summary_short": {
      "type": "string",
      "description": "Streszczenie sesji w 2-3 zdaniach (max 500 znaków)"
    },
    "speaker_role_inference": {
      "type": "object",
      "description": "Dedukowane role dla każdej etykiety mówcy z transkryptu. Klucze to speaker_tag (jako string: '1', '2', '3'). Dla każdego speakera: role + confidence + evidence z transkryptu.",
      "additionalProperties": {
        "type": "object",
        "properties": {
          "role": {
            "type": "string",
            "enum": ["therapist", "patient", "couple_partner", "family_member_parent", "family_member_child", "family_member_sibling", "third_party", "unknown"],
            "description": "Dedukowana rola na podstawie kontekstu rozmowy"
          },
          "confidence": {
            "type": "number",
            "description": "0-1, jak pewna jest dedukcja"
          },
          "evidence": {
            "type": "string",
            "description": "Krótkie uzasadnienie z transkryptu (max 200 znaków). Opisz co w sposobie wypowiedzi wskazuje na tę rolę."
          }
        },
        "required": ["role", "confidence", "evidence"]
      }
    },
    "main_themes": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "theme": {"type": "string"},
          "salience": {"type": "number", "description": "0-1 jak ważny był ten temat"},
          "evidence_quotes": {
            "type": "array",
            "items": {"type": "string"},
            "description": "Krótkie cytaty z transkryptu (max 3, każdy ≤ 100 znaków)"
          }
        },
        "required": ["theme", "salience", "evidence_quotes"]
      }
    },
    "therapeutic_alliance_observations": {
      "type": "string",
      "description": "Obserwacje dotyczące przymierza terapeutycznego (po dedukcji ról)"
    },
    "interventions_observed": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "intervention_type": {"type": "string"},
          "description": {"type": "string"},
          "patient_response": {"type": "string"}
        },
        "required": ["intervention_type", "description", "patient_response"]
      }
    },
    "hitop_dimensions": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "dimension_code": {
            "type": "string",
            "enum": ["INTERNALIZING", "EXTERNALIZING", "THOUGHT_DISORDER", "DETACHMENT", "DISTRESS", "FEAR", "DISTRESS_DEPRESSION", "DISTRESS_ANXIETY", "FEAR_PANIC", "FEAR_SOCIAL", "ANTAGONISM", "DISINHIBITION"],
            "description": "Kod wymiaru HiTOP (mierzonego dla pacjenta — po dedukcji ról)"
          },
          "score": {"type": "number", "description": "0-100"},
          "confidence": {"type": "number", "description": "0-1"},
          "evidence": {"type": "string", "description": "Krótkie uzasadnienie ≤ 200 znaków"}
        },
        "required": ["dimension_code", "score", "confidence", "evidence"]
      }
    },
    "risk_assessment": {
      "type": "object",
      "properties": {
        "level": {"type": "string", "enum": ["low", "medium", "high"]},
        "concerns": {
          "type": "array",
          "items": {"type": "string"}
        },
        "recommended_actions": {
          "type": "array",
          "items": {"type": "string"}
        }
      },
      "required": ["level", "concerns"]
    },
    "sentiment": {
      "type": "string",
      "enum": ["positive", "neutral", "concerning"]
    },
    "recommendations_for_next_session": {
      "type": "array",
      "items": {"type": "string"}
    },
    "rag_summary_chunk": {
      "type": "string",
      "description": "Krótkie streszczenie kluczowych informacji do zapisu w RAG memory (max 1500 znaków). NIE zawierać danych identyfikujących — używać tylko etykiet typu 'pacjent' (nie imion)."
    }
  },
  "required": [
    "title", "summary_short", "speaker_role_inference", "main_themes",
    "hitop_dimensions", "risk_assessment", "sentiment",
    "rag_summary_chunk"
  ]
}
EOF
```

### Task 2.6.2 — LLM worker code

```bash
cd services/ai-pipeline-svc/cmd/llm-worker

cat > main.go <<'EOF'
package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strings"
	"time"

	"cloud.google.com/go/aiplatform/apiv1/aiplatformpb"
	"cloud.google.com/go/pubsub"
	vertexai "cloud.google.com/go/vertexai/genai"
	"github.com/GoogleCloudPlatform/functions-framework-go/funcframework"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TranscriptCompletedEvent struct {
	SessionID    string `json:"session_id"`
	TranscriptID string `json:"transcript_id"`
}

type Event struct {
	Message struct {
		Data       []byte            `json:"data"`
		Attributes map[string]string `json:"attributes"`
	} `json:"message"`
}

var (
	dbPool       *pgxpool.Pool
	vertexClient *vertexai.Client
	pubsubClient *pubsub.Client
	projectID    string
	geminiModel  string = "gemini-2.5-pro"
	geminiRegion string = "europe-west4"
)

func init() {
	ctx := context.Background()
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)

	projectID = os.Getenv("GCP_PROJECT_ID")
	dbDSN := os.Getenv("DATABASE_URL")

	var err error
	dbPool, err = pgxpool.New(ctx, dbDSN)
	if err != nil {
		slog.Error("db", "error", err)
		os.Exit(1)
	}

	vertexClient, err = vertexai.NewClient(ctx, projectID, geminiRegion)
	if err != nil {
		slog.Error("vertex", "error", err)
		os.Exit(1)
	}

	pubsubClient, err = pubsub.NewClient(ctx, projectID)
	if err != nil {
		slog.Error("pubsub", "error", err)
		os.Exit(1)
	}

	funcframework.RegisterEventFunctionContext(ctx, "/", processTranscript)
}

func main() {
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if err := funcframework.Start(port); err != nil {
		slog.Error("framework", "error", err)
		os.Exit(1)
	}
}

func processTranscript(ctx context.Context, e Event) error {
	logger := slog.With("function", "llm-worker")

	var event TranscriptCompletedEvent
	data := e.Message.Data
	if decoded, err := base64.StdEncoding.DecodeString(string(data)); err == nil {
		data = decoded
	}
	if err := json.Unmarshal(data, &event); err != nil {
		logger.Error("parse event", "error", err)
		return err
	}

	logger = logger.With("session_id", event.SessionID, "transcript_id", event.TranscriptID)
	logger.Info("processing transcript")

	startTime := time.Now()

	// 1. Load session context
	session, err := loadSession(ctx, event.SessionID)
	if err != nil {
		return fmt.Errorf("load session: %w", err)
	}

	// 2. Load transcript z kanonicznego blob (ADR-IMPL-006)
	transcriptText, err := loadTranscriptText(ctx, event.TranscriptID)
	if err != nil {
		return fmt.Errorf("load transcript: %w", err)
	}

	// 3. Load modality prompt
	modalityPrompt, err := loadModalityPrompt(ctx, session.ModalityID)
	if err != nil {
		return fmt.Errorf("load prompt: %w", err)
	}

	// 4. Load RAG context (top 5 najbardziej relevantnych memories)
	ragContext, err := loadRAGContext(ctx, session.PatientFileID, transcriptText)
	if err != nil {
		logger.Warn("rag context", "error", err)
		ragContext = ""
	}

	// 5. Generate report z Gemini
	reportJSON, tokenStats, err := generateReport(ctx, modalityPrompt, ragContext, transcriptText)
	if err != nil {
		_ = updateSessionStatus(ctx, event.SessionID, "FAILED")
		return fmt.Errorf("generate: %w", err)
	}

	// 6. Parse + validate report
	var report ReportPayload
	if err := json.Unmarshal([]byte(reportJSON), &report); err != nil {
		return fmt.Errorf("parse report: %w", err)
	}

	// 7. Persist report + HiTOP measurements
	reportID, err := persistReport(ctx, session, event.TranscriptID, &report, reportJSON, tokenStats, time.Since(startTime))
	if err != nil {
		return fmt.Errorf("persist: %w", err)
	}

	// 8. Generate embedding dla RAG memory chunk
	embedding, err := generateEmbedding(ctx, report.RAGSummaryChunk)
	if err != nil {
		logger.Warn("embedding", "error", err)
	} else {
		if err := persistRAGMemory(ctx, session, reportID, &report, embedding); err != nil {
			logger.Warn("rag persist", "error", err)
		}
	}

	// 9. Update status COMPLETED
	if err := updateSessionStatus(ctx, event.SessionID, "COMPLETED"); err != nil {
		logger.Warn("status", "error", err)
	}

	// 10. Publish report.generated
	_ = publishReportGenerated(ctx, event.SessionID, reportID)

	logger.Info("done",
		"report_id", reportID,
		"duration_ms", time.Since(startTime).Milliseconds(),
		"input_tokens", tokenStats.InputTokens,
		"output_tokens", tokenStats.OutputTokens)

	return nil
}

type SessionContext struct {
	ID                  uuid.UUID
	PatientFileID       uuid.UUID
	ModalityID          uuid.UUID
	LanguageCode        string
	SpeakerLabelMapping map[int32]string  // {1: "Osoba 1", 2: "Osoba 2"}
}

type ReportPayload struct {
	Title                   string                            `json:"title"`
	SummaryShort            string                            `json:"summary_short"`
	SpeakerRoleInference    map[string]SpeakerRoleInference   `json:"speaker_role_inference"`
	MainThemes              []ThemeItem                       `json:"main_themes"`
	HiTOPDimensions         []HiTOPItem                       `json:"hitop_dimensions"`
	RiskAssessment          RiskAssessment                    `json:"risk_assessment"`
	Sentiment               string                            `json:"sentiment"`
	RAGSummaryChunk         string                            `json:"rag_summary_chunk"`
}

type SpeakerRoleInference struct {
	Role       string  `json:"role"`         // 'therapist', 'patient', 'couple_partner', etc.
	Confidence float64 `json:"confidence"`
	Evidence   string  `json:"evidence"`
}

type ThemeItem struct {
	Theme    string   `json:"theme"`
	Salience float64  `json:"salience"`
	Evidence []string `json:"evidence_quotes"`
}

type HiTOPItem struct {
	DimensionCode string  `json:"dimension_code"`
	Score         float64 `json:"score"`
	Confidence    float64 `json:"confidence"`
	Evidence      string  `json:"evidence"`
}

type RiskAssessment struct {
	Level    string   `json:"level"`
	Concerns []string `json:"concerns"`
}

type TokenStats struct {
	InputTokens  int32
	OutputTokens int32
}

func generateReport(ctx context.Context, modalityPrompt, ragContext, transcriptText string) (string, TokenStats, error) {
	model := vertexClient.GenerativeModel(geminiModel)

	// Load schema
	schemaBytes, _ := os.ReadFile("schemas/report_schema.json")
	var schema map[string]any
	json.Unmarshal(schemaBytes, &schema)

	model.GenerationConfig = vertexai.GenerationConfig{
		Temperature:      vertexai.Ptr[float32](0.2),
		TopP:             vertexai.Ptr[float32](0.95),
		MaxOutputTokens:  vertexai.Ptr[int32](8192),
		ResponseMIMEType: "application/json",
		ResponseSchema:   schemaToVertexSchema(schema),
	}

	prompt := fmt.Sprintf(`%s

UWAGA O ETYKIETACH MÓWCÓW:
Transkrypt zawiera neutralne etykiety mówców (np. "Osoba 1", "Osoba 2" lub "Person 1", "Person 2") — to NIE są role, tylko numeracja.
Twoim zadaniem jest **dedukować role z kontekstu rozmowy** i zapisać dedukcję w polu speaker_role_inference.

Wskazówki dot. dedukcji ról:
- Osoba pełniąca rolę terapeuty zazwyczaj: zadaje pytania otwarte, stosuje techniki (np. socratic questioning, reflektowanie), używa fachowego języka, kieruje rozmową.
- Osoba pełniąca rolę pacjenta zazwyczaj: opisuje swoje odczucia/objawy, odpowiada na pytania, mówi o sobie w pierwszej osobie o problemach.
- W sesjach par/rodzin: wskaż couple_partner / family_member_*. Jeśli niejasne — użyj 'unknown'.
- Confidence: 0.9+ jeśli wzorce są jednoznaczne, 0.5-0.8 jeśli są wskazówki ale nie pewność, < 0.5 jeśli niejasne.

KONTEKST POPRZEDNICH SESJI:
%s

TRANSKRYPT BIEŻĄCEJ SESJI:
%s

Wygeneruj raport zgodny z podanym JSON Schema. Pamiętaj o:
- Dedukcji ról dla KAŻDEJ etykiety mówcy w transkrypcie (speaker_role_inference).
- Cytatach maksymalnie 100 znaków każdy.
- Skali HiTOP: 0-100 score, 0-1 confidence (mierzymy DLA pacjenta — używaj tylko wypowiedzi osoby zdedukowanej jako 'patient').
- RAG summary chunk: NIE zawierać danych identyfikujących — używać tylko etykiet typu "pacjent" (nie imion ani neutralnych labels).`,
		modalityPrompt, ragContext, transcriptText)

	resp, err := model.GenerateContent(ctx, vertexai.Text(prompt))
	if err != nil {
		return "", TokenStats{}, err
	}

	if len(resp.Candidates) == 0 || resp.Candidates[0].Content == nil {
		return "", TokenStats{}, fmt.Errorf("no candidates returned")
	}

	var output strings.Builder
	for _, part := range resp.Candidates[0].Content.Parts {
		if text, ok := part.(vertexai.Text); ok {
			output.WriteString(string(text))
		}
	}

	stats := TokenStats{}
	if resp.UsageMetadata != nil {
		stats.InputTokens = resp.UsageMetadata.PromptTokenCount
		stats.OutputTokens = resp.UsageMetadata.CandidatesTokenCount
	}

	return output.String(), stats, nil
}

func schemaToVertexSchema(s map[string]any) *vertexai.Schema {
	// Konwersja JSON Schema → Vertex AI Schema (uproszczone)
	schemaJSON, _ := json.Marshal(s)
	var vs vertexai.Schema
	_ = json.Unmarshal(schemaJSON, &vs)
	return &vs
}

func generateEmbedding(ctx context.Context, text string) ([]float32, error) {
	// Use textembedding-gecko via Vertex AI
	// W Fazie 2: stub embedding (np. zera lub random)
	// W Fazie 3: real Vertex embeddings call
	return make([]float32, 768), nil
}

// SQL helpers (simplified)

func loadSession(ctx context.Context, sessionID string) (*SessionContext, error) {
	id, err := uuid.Parse(sessionID)
	if err != nil {
		return nil, err
	}

	var sc SessionContext
	sc.ID = id

	var mappingJSON []byte
	var langCode *string
	row := dbPool.QueryRow(ctx, `
		SELECT s.patient_file_id, pf.modality_id, s.speaker_label_mapping, s.language_code
		FROM sessions s
		JOIN patient_files pf ON pf.id = s.patient_file_id
		WHERE s.id = $1`, id)
	if err := row.Scan(&sc.PatientFileID, &sc.ModalityID, &mappingJSON, &langCode); err != nil {
		return nil, err
	}

	if langCode != nil {
		sc.LanguageCode = *langCode
	}

	mapping := map[string]string{}
	json.Unmarshal(mappingJSON, &mapping)

	sc.SpeakerLabelMapping = make(map[int32]string)
	for k, v := range mapping {
		var tag int32
		fmt.Sscanf(k, "%d", &tag)
		sc.SpeakerLabelMapping[tag] = v
	}

	return &sc, nil
}

// loadTranscriptText czyta transkrypt z KANONICZNEGO blob'a w transcripts (ADR-IMPL-006).
// NIE iteruje po segments — pełny tekst jest jednym zaszyfrowanym JSON-em.
//
// Format blob (po decrypt): JSON array z {speaker_tag, speaker_label, text, start_ms, end_ms}.
// Zwraca sformatowany tekst dla LLM:
//   "[Osoba 1] (1200ms-4500ms) Cześć, jak się czujesz dzisiaj?"
//   "[Osoba 2] (4600ms-7800ms) Trochę zmęczona, ale ogólnie dobrze."
func loadTranscriptText(ctx context.Context, transcriptID string) (string, error) {
	id, _ := uuid.Parse(transcriptID)

	var ciphertext []byte
	row := dbPool.QueryRow(ctx,
		"SELECT transcript_ciphertext FROM transcripts WHERE id = $1", id)
	if err := row.Scan(&ciphertext); err != nil {
		return "", err
	}

	// PRODUCTION: decrypt z Cloud KMS (envelope encryption).
	// Faza 2 — strip placeholder.
	blobJSON := strings.TrimPrefix(string(ciphertext), "ENCRYPT_PLACEHOLDER:")

	type BlobLine struct {
		SpeakerTag   int32  `json:"speaker_tag"`
		SpeakerLabel string `json:"speaker_label"`
		Text         string `json:"text"`
		StartMS      int64  `json:"start_ms"`
		EndMS        int64  `json:"end_ms"`
	}

	var lines []BlobLine
	if err := json.Unmarshal([]byte(blobJSON), &lines); err != nil {
		return "", fmt.Errorf("unmarshal transcript blob: %w", err)
	}

	var sb strings.Builder
	for _, l := range lines {
		fmt.Fprintf(&sb, "[%s] (%dms-%dms) %s\n", l.SpeakerLabel, l.StartMS, l.EndMS, l.Text)
	}

	return sb.String(), nil
}

func loadModalityPrompt(ctx context.Context, modalityID uuid.UUID) (string, error) {
	var promptJSON []byte
	row := dbPool.QueryRow(ctx,
		"SELECT therapist_ai_general_prompt FROM modalities WHERE id = $1", modalityID)
	if err := row.Scan(&promptJSON); err != nil {
		return "", err
	}

	var prompt map[string]string
	json.Unmarshal(promptJSON, &prompt)
	return prompt["system"], nil
}

func loadRAGContext(ctx context.Context, patientFileID uuid.UUID, currentText string) (string, error) {
	// W Fazie 2 stub — return empty.
	// W Fazie 3 generate query embedding + similarity search via pgvector.
	return "", nil
}

func persistReport(ctx context.Context, session *SessionContext, transcriptID string, report *ReportPayload, fullJSON string, tokenStats TokenStats, processingTime time.Duration) (string, error) {
	transID, _ := uuid.Parse(transcriptID)
	reportID := uuid.New()

	ciphertext := []byte("ENCRYPT_PLACEHOLDER:" + fullJSON)
	encDEK := []byte("DEK_PLACEHOLDER")

	tx, err := dbPool.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer tx.Rollback(ctx)

	costUSD := float64(tokenStats.InputTokens)*0.00000125 + float64(tokenStats.OutputTokens)*0.000005

	// Marshal speaker_role_inference dla JSONB column
	roleInferenceJSON, _ := json.Marshal(report.SpeakerRoleInference)

	_, err = tx.Exec(ctx, `
		INSERT INTO reports (id, session_id, transcript_id, modality_id,
			report_ciphertext, report_encrypted_dek, title, summary_short,
			sentiment_label, risk_level, speaker_role_inference,
			llm_model, llm_input_tokens,
			llm_output_tokens, llm_processing_seconds, llm_total_cost_usd)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)`,
		reportID, session.ID, transID, session.ModalityID,
		ciphertext, encDEK, report.Title, report.SummaryShort,
		report.Sentiment, report.RiskAssessment.Level, roleInferenceJSON,
		geminiModel,
		tokenStats.InputTokens, tokenStats.OutputTokens,
		int(processingTime.Seconds()), costUSD)
	if err != nil {
		return "", err
	}

	// HiTOP measurements
	for _, h := range report.HiTOPDimensions {
		var dimID uuid.UUID
		err := tx.QueryRow(ctx,
			"SELECT id FROM hitop_dimensions WHERE code = $1", h.DimensionCode).Scan(&dimID)
		if err == pgx.ErrNoRows {
			// Auto-create dimension if not exists (Faza 2 quick-and-dirty; Faza 3 strict)
			dimID = uuid.New()
			_, _ = tx.Exec(ctx,
				"INSERT INTO hitop_dimensions (id, code, display_name, level) VALUES ($1, $2, $2, 'syndrome')",
				dimID, h.DimensionCode)
		} else if err != nil {
			continue
		}

		evidenceCipher := []byte("ENCRYPT_PLACEHOLDER:" + h.Evidence)
		evidenceDEK := []byte("DEK_PLACEHOLDER")

		_, err = tx.Exec(ctx, `
			INSERT INTO hitop_measurements (session_id, report_id, dimension_id,
				score, confidence, evidence_ciphertext, evidence_encrypted_dek)
			VALUES ($1, $2, $3, $4, $5, $6, $7)
			ON CONFLICT (session_id, dimension_id) DO UPDATE
			SET score = EXCLUDED.score, confidence = EXCLUDED.confidence`,
			session.ID, reportID, dimID, h.Score, h.Confidence, evidenceCipher, evidenceDEK)
		if err != nil {
			continue
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}

	return reportID.String(), nil
}

func persistRAGMemory(ctx context.Context, session *SessionContext, reportID string, report *ReportPayload, embedding []float32) error {
	repID, _ := uuid.Parse(reportID)

	summaryCipher := []byte("ENCRYPT_PLACEHOLDER:" + report.RAGSummaryChunk)
	summaryDEK := []byte("DEK_PLACEHOLDER")

	// Convert embedding to pgvector format string
	embeddingStr := vectorToString(embedding)

	_, err := dbPool.Exec(ctx, `
		INSERT INTO rag_memories (patient_file_id, source_session_id, source_report_id,
			summary_ciphertext, summary_encrypted_dek, embedding,
			chunk_type, importance_score)
		VALUES ($1, $2, $3, $4, $5, $6::vector, 'summary', 0.7)`,
		session.PatientFileID, session.ID, repID, summaryCipher, summaryDEK, embeddingStr)
	return err
}

func vectorToString(v []float32) string {
	var sb strings.Builder
	sb.WriteString("[")
	for i, x := range v {
		if i > 0 {
			sb.WriteString(",")
		}
		fmt.Fprintf(&sb, "%f", x)
	}
	sb.WriteString("]")
	return sb.String()
}

func updateSessionStatus(ctx context.Context, sessionID, status string) error {
	id, _ := uuid.Parse(sessionID)
	_, err := dbPool.Exec(ctx,
		"UPDATE sessions SET status = $1, status_updated_at = now() WHERE id = $2",
		status, id)
	return err
}

func publishReportGenerated(ctx context.Context, sessionID, reportID string) error {
	topic := pubsubClient.Topic("report.generated")
	defer topic.Stop()

	payload, _ := json.Marshal(map[string]string{
		"session_id": sessionID,
		"report_id":  reportID,
	})
	res := topic.Publish(ctx, &pubsub.Message{Data: payload})
	_, err := res.Get(ctx)
	return err
}

// Stub for unused import
var _ = aiplatformpb.PredictRequest{}
EOF
```

### Task 2.6.3 — Deploy LLM worker

```bash
gcloud functions deploy llm-worker \
  --gen2 \
  --runtime=go122 \
  --region=europe-central2 \
  --project=superwizor-staging \
  --source=services/ai-pipeline-svc/cmd/llm-worker \
  --entry-point=cloudevent \
  --trigger-topic=transcript.completed \
  --service-account=llm-worker@superwizor-staging.iam.gserviceaccount.com \
  --vpc-connector=swvpc-connector \
  --memory=2Gi \
  --cpu=2 \
  --timeout=540s \
  --max-instances=5 \
  --concurrency=1 \
  --set-env-vars="GCP_PROJECT_ID=superwizor-staging" \
  --set-secrets="DATABASE_URL=postgres-database-url:latest"
```

---

## Sprint 2.6.5 — UpdateSpeakerLabels endpoint (rebuild flow)

**Czas:** 1 dzień (mieści się w Sprint 2.6)
**Cel:** Endpoint w `clinical-svc` pozwalający terapeucie zmienić labels (`Osoba 1 → Anna`, `Osoba 2 → Marek`) i regenerujący kanoniczny blob `transcripts.transcript_ciphertext`.

### Task 2.6.5.1 — Proto extension w clinical-svc

```bash
# Dodaj do proto/clinical/v1/clinical.proto:

service ClinicalService {
  // ... istniejące endpointy ...

  // Aktualizuje labels mówców dla sesji + rebuilduje transcript blob.
  rpc UpdateSpeakerLabels(UpdateSpeakerLabelsRequest) returns (UpdateSpeakerLabelsResponse);
}

message UpdateSpeakerLabelsRequest {
  string session_id = 1;
  // Mapping: speaker_tag (jako string "1", "2", "3") → nowy label
  // Przykład: {"1": "Anna Kowalska", "2": "Marek Kowalski"}
  map<string, string> label_mapping = 2;
}

message UpdateSpeakerLabelsResponse {
  string session_id = 1;
  string transcript_id = 2;
  int32 segments_updated = 3;
  bool blob_rebuilt = 4;
}
```

### Task 2.6.5.2 — sqlc queries

```bash
# services/clinical-svc/internal/adapters/postgres/queries/labels.sql

-- name: GetTranscriptForRebuild :one
SELECT t.id AS transcript_id, t.session_id, t.language_code
FROM transcripts t
WHERE t.session_id = $1
ORDER BY t.created_at DESC
LIMIT 1;

-- name: ListSegmentsForRebuild :many
SELECT speaker_tag, text_ciphertext, text_encrypted_dek,
       start_offset_ms, end_offset_ms, confidence
FROM transcript_segments
WHERE transcript_id = $1
ORDER BY start_offset_ms;

-- name: UpdateTranscriptBlob :exec
UPDATE transcripts SET
    transcript_ciphertext = $2,
    transcript_encrypted_dek = $3,
    blob_rebuilt_at = now(),
    blob_rebuild_count = blob_rebuild_count + 1
WHERE id = $1;

-- name: UpdateSegmentLabel :exec
UPDATE transcript_segments SET speaker_label = $3
WHERE transcript_id = $1 AND speaker_tag = $2;

-- name: UpdateSessionLabelMapping :exec
UPDATE sessions SET speaker_label_mapping = $2
WHERE id = $1;
```

### Task 2.6.5.3 — Implementation

```go
// services/clinical-svc/internal/adapters/grpc/labels.go

func (s *Server) UpdateSpeakerLabels(ctx context.Context, req *clinicalv1.UpdateSpeakerLabelsRequest) (*clinicalv1.UpdateSpeakerLabelsResponse, error) {
	sessionID, err := uuid.Parse(req.SessionId)
	if err != nil {
		return nil, status.Error(codes.InvalidArgument, "invalid session_id")
	}

	if len(req.LabelMapping) == 0 {
		return nil, status.Error(codes.InvalidArgument, "label_mapping required")
	}

	// Walidacja: każdy label musi być niepusty, max 50 znaków, brak whitespace-only
	for tag, label := range req.LabelMapping {
		trimmed := strings.TrimSpace(label)
		if trimmed == "" {
			return nil, status.Errorf(codes.InvalidArgument, "label for speaker_tag %s cannot be empty", tag)
		}
		if len(trimmed) > 50 {
			return nil, status.Errorf(codes.InvalidArgument, "label for speaker_tag %s exceeds 50 chars", tag)
		}
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}
	defer tx.Rollback(ctx)

	qtx := s.queries.WithTx(tx)

	// 1. Get latest transcript dla sesji
	transcript, err := qtx.GetTranscriptForRebuild(ctx, sessionID)
	if err != nil {
		return nil, status.Error(codes.NotFound, "no transcript found for session")
	}

	// 2. Load wszystkie segmenty
	segments, err := qtx.ListSegmentsForRebuild(ctx, transcript.TranscriptID)
	if err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// 3. Build new blob z aktualizowanymi labels
	type BlobLine struct {
		SpeakerTag   int32   `json:"speaker_tag"`
		SpeakerLabel string  `json:"speaker_label"`
		Text         string  `json:"text"`
		StartMS      int64   `json:"start_ms"`
		EndMS        int64   `json:"end_ms"`
		Confidence   float32 `json:"confidence"`
	}

	blobLines := make([]BlobLine, 0, len(segments))
	for _, seg := range segments {
		// Decrypt segment text (placeholder w Faza 2; KMS w Faza 3)
		segText := strings.TrimPrefix(string(seg.TextCiphertext), "ENCRYPT_PLACEHOLDER:")

		// Apply nowy label (jeśli w mapping; inaczej zostaw obecny)
		newLabel, hasUpdate := req.LabelMapping[fmt.Sprintf("%d", seg.SpeakerTag)]
		if !hasUpdate {
			// Zachowaj poprzedni label z DB — nie wszystkie speakers muszą być w mapping
			row := tx.QueryRow(ctx,
				"SELECT speaker_label FROM transcript_segments WHERE transcript_id = $1 AND speaker_tag = $2 LIMIT 1",
				transcript.TranscriptID, seg.SpeakerTag)
			row.Scan(&newLabel)
		}

		blobLines = append(blobLines, BlobLine{
			SpeakerTag:   seg.SpeakerTag,
			SpeakerLabel: newLabel,
			Text:         segText,
			StartMS:      int64(seg.StartOffsetMs),
			EndMS:        int64(seg.EndOffsetMs),
			Confidence:   ptrFloat32(seg.Confidence),
		})
	}

	blobJSON, _ := json.Marshal(blobLines)

	// PRODUCTION: encrypt z Cloud KMS
	newCiphertext := []byte("ENCRYPT_PLACEHOLDER:" + string(blobJSON))
	newDEK := []byte("DEK_PLACEHOLDER")

	// 4. Update transcripts (rebuild blob)
	if err := qtx.UpdateTranscriptBlob(ctx, db.UpdateTranscriptBlobParams{
		ID:                     transcript.TranscriptID,
		TranscriptCiphertext:   newCiphertext,
		TranscriptEncryptedDek: newDEK,
	}); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// 5. Update transcript_segments.speaker_label per tag w mapping
	for tagStr, newLabel := range req.LabelMapping {
		var tag int32
		fmt.Sscanf(tagStr, "%d", &tag)

		if err := qtx.UpdateSegmentLabel(ctx, db.UpdateSegmentLabelParams{
			TranscriptID: transcript.TranscriptID,
			SpeakerTag:   tag,
			SpeakerLabel: strings.TrimSpace(newLabel),
		}); err != nil {
			return nil, status.Error(codes.Internal, err.Error())
		}
	}

	// 6. Update sessions.speaker_label_mapping
	mappingJSON, _ := json.Marshal(req.LabelMapping)
	if err := qtx.UpdateSessionLabelMapping(ctx, db.UpdateSessionLabelMappingParams{
		ID:                  sessionID,
		SpeakerLabelMapping: mappingJSON,
	}); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	// 7. Audit
	auditMeta, _ := json.Marshal(map[string]any{
		"transcript_id": transcript.TranscriptID.String(),
		"label_changes": req.LabelMapping,
	})
	_ = qtx.CreateAuditEvent(ctx, db.CreateAuditEventParams{
		Action:       "session.update_speaker_labels",
		ResourceType: "session",
		ResourceID:   &sessionID,
		Metadata:     auditMeta,
	})

	if err := tx.Commit(ctx); err != nil {
		return nil, status.Error(codes.Internal, err.Error())
	}

	return &clinicalv1.UpdateSpeakerLabelsResponse{
		SessionId:       sessionID.String(),
		TranscriptId:    transcript.TranscriptID.String(),
		SegmentsUpdated: int32(len(req.LabelMapping)),
		BlobRebuilt:     true,
	}, nil
}

func ptrFloat32(p *float64) float32 {
	if p == nil {
		return 0
	}
	return float32(*p)
}
```

### Task 2.6.5.4 — Test scenariusz

```bash
TOKEN=$(gcloud auth print-identity-token)
URL=$(gcloud run services describe clinical-svc --region=europe-central2 --project=superwizor-staging --format="value(status.url)" | sed 's|https://||')

# Najpierw sesja musi istnieć z transkryptem (po Sprint 2.5)
SESSION_ID="..."  # z poprzedniego E2E

# Update labels: Osoba 1 → Anna, Osoba 2 → Marek
grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d "{
    \"session_id\": \"${SESSION_ID}\",
    \"label_mapping\": {
      \"1\": \"Anna\",
      \"2\": \"Marek\"
    }
  }" \
  ${URL}:443 \
  clinical.v1.ClinicalService/UpdateSpeakerLabels

# Verify w DB:
psql -h 127.0.0.1 -U postgres -d superwizor -c "
  SELECT speaker_label_mapping, blob_rebuild_count
  FROM sessions s
  JOIN transcripts t ON t.session_id = s.id
  WHERE s.id = '${SESSION_ID}';
"

# Verify blob zawiera nowe labels po decrypt (Faza 2 placeholder):
psql -h 127.0.0.1 -U postgres -d superwizor -c "
  SELECT replace(transcript_ciphertext::text, 'ENCRYPT_PLACEHOLDER:', '')::jsonb
  FROM transcripts
  WHERE session_id = '${SESSION_ID}';
"
```



**Czas:** 2 dni
**Cel:** Wakelock + chunking 30s + signed URL upload.

### Task 2.7.1 — Add packages

```bash
cd flutter-app/superwizor

flutter pub add \
  record \
  wakelock_plus \
  http \
  path_provider \
  permission_handler \
  uuid
```

### Task 2.7.2 — RecordingService

```bash
mkdir -p lib/services

cat > lib/services/recording_service.dart <<'EOF'
import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum RecordingState { idle, recording, paused, stopped, error }

class AudioChunk {
  final String filePath;
  final int chunkIndex;
  final int durationMs;

  AudioChunk({required this.filePath, required this.chunkIndex, required this.durationMs});
}

class RecordingService {
  final _recorder = AudioRecorder();
  final _stateController = StreamController<RecordingState>.broadcast();
  final _chunkController = StreamController<AudioChunk>.broadcast();

  Timer? _chunkTimer;
  String? _sessionDir;
  int _chunkIndex = 0;
  DateTime? _chunkStartTime;
  RecordingState _state = RecordingState.idle;

  static const _chunkDurationSeconds = 30;

  Stream<RecordingState> get stateStream => _stateController.stream;
  Stream<AudioChunk> get chunkStream => _chunkController.stream;
  RecordingState get state => _state;

  Future<bool> hasPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> startRecording(String sessionId) async {
    if (!await hasPermission()) {
      _setState(RecordingState.error);
      throw Exception('Microphone permission denied');
    }

    final docs = await getApplicationDocumentsDirectory();
    _sessionDir = p.join(docs.path, 'recordings', sessionId);
    await Directory(_sessionDir!).create(recursive: true);

    _chunkIndex = 0;
    await WakelockPlus.enable();

    await _startNewChunk();

    // Schedule chunk rotation
    _chunkTimer = Timer.periodic(
      const Duration(seconds: _chunkDurationSeconds),
      (_) => _rotateChunk(),
    );

    _setState(RecordingState.recording);
  }

  Future<void> _startNewChunk() async {
    final filePath = p.join(_sessionDir!, 'chunk_${_chunkIndex.toString().padLeft(4, '0')}.m4a');
    _chunkStartTime = DateTime.now();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 64000,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: filePath,
    );
  }

  Future<void> _rotateChunk() async {
    if (_state != RecordingState.recording) return;

    final completedPath = await _recorder.stop();
    if (completedPath != null && _chunkStartTime != null) {
      final durationMs = DateTime.now().difference(_chunkStartTime!).inMilliseconds;
      _chunkController.add(AudioChunk(
        filePath: completedPath,
        chunkIndex: _chunkIndex,
        durationMs: durationMs,
      ));
    }

    _chunkIndex++;
    await _startNewChunk();
  }

  Future<void> pauseRecording() async {
    if (_state == RecordingState.recording) {
      await _recorder.pause();
      _chunkTimer?.cancel();
      _setState(RecordingState.paused);
    }
  }

  Future<void> resumeRecording() async {
    if (_state == RecordingState.paused) {
      await _recorder.resume();
      _chunkTimer = Timer.periodic(
        const Duration(seconds: _chunkDurationSeconds),
        (_) => _rotateChunk(),
      );
      _setState(RecordingState.recording);
    }
  }

  Future<List<String>> stopRecording() async {
    _chunkTimer?.cancel();

    final lastPath = await _recorder.stop();
    if (lastPath != null && _chunkStartTime != null) {
      final durationMs = DateTime.now().difference(_chunkStartTime!).inMilliseconds;
      _chunkController.add(AudioChunk(
        filePath: lastPath,
        chunkIndex: _chunkIndex,
        durationMs: durationMs,
      ));
    }

    await WakelockPlus.disable();
    _setState(RecordingState.stopped);

    if (_sessionDir == null) return [];

    final dir = Directory(_sessionDir!);
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.m4a'))
        .map((e) => e.path)
        .toList();

    files.sort();
    return files;
  }

  void _setState(RecordingState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void dispose() {
    _chunkTimer?.cancel();
    _stateController.close();
    _chunkController.close();
    _recorder.dispose();
  }
}
EOF
```

### Task 2.7.3 — UploadService

```bash
cat > lib/services/upload_service.dart <<'EOF'
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

class UploadService {
  static const _maxRetries = 3;
  static const _retryBaseDelayMs = 1000;

  /// Combines chunk files into one m4a (placeholder — w prod używać ffmpeg lub native).
  /// W Fazie 2 zakładamy że chunki są wysyłane jako jeden ostatni plik
  /// (concatenation server-side w Cloud Functions albo client-side przez ffmpeg).
  Future<Uint8List> combineChunks(List<String> chunkPaths) async {
    final buffer = BytesBuilder();
    for (final path in chunkPaths) {
      final bytes = await File(path).readAsBytes();
      buffer.add(bytes);
    }
    return buffer.takeBytes();
  }

  /// Upload audio bytes to signed URL with retry policy.
  Future<bool> uploadToSignedUrl({
    required String signedUrl,
    required Uint8List audioBytes,
    required String contentType,
    void Function(double progress)? onProgress,
  }) async {
    final md5Hash = md5.convert(audioBytes).toString();

    for (var attempt = 0; attempt < _maxRetries; attempt++) {
      try {
        final response = await http.put(
          Uri.parse(signedUrl),
          headers: {
            'Content-Type': contentType,
            'Content-MD5': md5Hash,
            'x-goog-meta-source': 'superwizor-mobile',
          },
          body: audioBytes,
        );

        if (response.statusCode == 200 || response.statusCode == 204) {
          return true;
        }

        // Retry on 5xx, fail on 4xx
        if (response.statusCode >= 400 && response.statusCode < 500) {
          throw Exception('Upload rejected: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        if (attempt == _maxRetries - 1) rethrow;

        // Exponential backoff
        final delayMs = _retryBaseDelayMs * (1 << attempt);
        await Future.delayed(Duration(milliseconds: delayMs));
      }
    }

    return false;
  }
}
EOF
```

### Task 2.7.4 — Recording UI

```bash
cat > lib/screens/recording_screen.dart <<'EOF'
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../services/recording_service.dart';
import '../services/upload_service.dart';

class RecordingScreen extends StatefulWidget {
  final String patientFileId;
  final String therapistId;

  const RecordingScreen({super.key, required this.patientFileId, required this.therapistId});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final _recorder = RecordingService();
  final _uploader = UploadService();

  String? _sessionId;
  Duration _elapsed = Duration.zero;
  int _chunkCount = 0;
  bool _uploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _recorder.chunkStream.listen((chunk) {
      setState(() => _chunkCount++);
    });
  }

  Future<void> _start() async {
    _sessionId = const Uuid().v4();
    await _recorder.startRecording(_sessionId!);

    // Update timer co sekundę
    Stream.periodic(const Duration(seconds: 1)).take(7200).listen((tick) {
      if (mounted && _recorder.state == RecordingState.recording) {
        setState(() => _elapsed = Duration(seconds: tick + 1));
      }
    });

    setState(() {});
  }

  Future<void> _stop() async {
    setState(() => _uploading = true);

    try {
      final chunkPaths = await _recorder.stopRecording();

      // 1. Połącz chunki w jeden plik (w prod: native ffmpeg)
      final combined = await _uploader.combineChunks(chunkPaths);

      // 2. Pobierz signed URL z ingestion-svc (placeholder — gRPC call)
      // TODO: prawdziwe gRPC wywołanie, dla przykładu hardcoded
      final signedUrl = await _requestSignedUrl(combined.length);

      // 3. PUT do GCS
      final ok = await _uploader.uploadToSignedUrl(
        signedUrl: signedUrl,
        audioBytes: combined,
        contentType: 'audio/m4a',
      );

      if (!ok) throw Exception('Upload failed');

      // 4. Notify ingestion-svc że upload się zakończył
      await _completeUpload();

      if (mounted) {
        Navigator.pop(context, _sessionId);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<String> _requestSignedUrl(int sizeBytes) async {
    // TODO: real gRPC call do ingestion-svc.CreateAudioUpload
    throw UnimplementedError('Implement gRPC client call');
  }

  Future<void> _completeUpload() async {
    // TODO: real gRPC call do ingestion-svc.CompleteAudioUpload
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF004D54),
      appBar: AppBar(
        backgroundColor: const Color(0xFF004D54),
        title: const Text('Nagrywanie sesji.', style: TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _recorder.state == RecordingState.recording
                    ? Icons.fiber_manual_record
                    : Icons.mic,
                color: const Color(0xFFFCAE2F),
                size: 96,
              ),
              const SizedBox(height: 24),
              Text(
                _formatDuration(_elapsed),
                style: const TextStyle(color: Colors.white, fontSize: 48),
              ),
              const SizedBox(height: 16),
              Text(
                'Chunki zapisane: $_chunkCount',
                style: const TextStyle(color: Colors.white70),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 48),
              if (_uploading)
                const CircularProgressIndicator(color: Color(0xFFFCAE2F))
              else if (_recorder.state == RecordingState.idle)
                ElevatedButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Rozpocznij nagrywanie.'),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFCAE2F)),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_recorder.state == RecordingState.recording)
                      ElevatedButton(onPressed: _recorder.pauseRecording, child: const Text('Pauza.'))
                    else
                      ElevatedButton(onPressed: _recorder.resumeRecording, child: const Text('Wznów.')),
                    ElevatedButton(
                      onPressed: _stop,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Zakończ i wyślij.'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }
}
EOF
```

### Task 2.7.5 — iOS/Android permissions

**iOS** — `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>SuperWizor potrzebuje dostępu do mikrofonu, aby nagrywać sesje terapeutyczne.</string>
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

**Android** — `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
```

---

## Sprint 2.8 — E2E test

**Czas:** 2 dni

### Task 2.8.1 — E2E test scenariusz

```bash
cat > tests/e2e/test_full_pipeline.sh <<'EOF'
#!/bin/bash
set -euo pipefail

PROJECT_ID="superwizor-staging"
REGION="europe-central2"

echo "=== Step 1: Stwórz patient_file ==="
# (zakładamy że identity-svc + clinical-svc działają z Fazy 1)
PATIENT_FILE_ID=$(grpcurl ... CreatePatientFile | jq -r .id)

echo "=== Step 2: Pobierz signed URL ==="
SIGNED_URL=$(grpcurl ... CreateAudioUpload | jq -r .signed_url)

echo "=== Step 3: Upload testowego audio ==="
curl -X PUT \
  -H "Content-Type: audio/m4a" \
  --data-binary @tests/fixtures/test_session_90s.m4a \
  "${SIGNED_URL}"

echo "=== Step 4: Notify completion ==="
SESSION_ID=$(grpcurl ... CompleteAudioUpload | jq -r .session_id)

echo "=== Step 5: Wait for STT (60-180s) ==="
for i in {1..60}; do
  STATUS=$(psql -h 127.0.0.1 -U postgres -d superwizor -t -c \
    "SELECT status FROM sessions WHERE id = '${SESSION_ID}'" | tr -d ' ')

  echo "  attempt $i: status=$STATUS"

  if [ "$STATUS" = "COMPLETED" ]; then break; fi
  if [ "$STATUS" = "FAILED" ]; then
    echo "❌ pipeline FAILED"
    exit 1
  fi
  sleep 5
done

echo "=== Step 6: Verify report w DB ==="
psql -h 127.0.0.1 -U postgres -d superwizor -c "
  SELECT id, title, sentiment_label, risk_level, llm_total_cost_usd
  FROM reports
  WHERE session_id = '${SESSION_ID}';
"

echo "=== Step 7: Verify HiTOP measurements ==="
psql -h 127.0.0.1 -U postgres -d superwizor -c "
  SELECT hd.code, hm.score, hm.confidence
  FROM hitop_measurements hm
  JOIN hitop_dimensions hd ON hd.id = hm.dimension_id
  WHERE hm.session_id = '${SESSION_ID}';
"

echo "=== Step 8: Verify RAG memory ==="
psql -h 127.0.0.1 -U postgres -d superwizor -c "
  SELECT id, chunk_type, importance_score, created_at
  FROM rag_memories
  WHERE source_session_id = '${SESSION_ID}';
"

echo "✅ E2E pipeline passed"
EOF

chmod +x tests/e2e/test_full_pipeline.sh
```

---

## Troubleshooting cookbook

### Problem 1: "Chirp 3 model not found in europe-central2"

**Symptom:** `INVALID_ARGUMENT: Model 'chirp_3' is not available in this region`.

**Fix:** Chirp 3 wymaga regionów `us-central1`, `europe-west4`, `asia-southeast1`. STT worker wywołuje cross-region (zob. ADR-IMPL-001). Audio transit jest acceptable bo Google to internal traffic w UE.

### Problem 2: Vertex AI Gemini "Resource exhausted"

**Symptom:** `RESOURCE_EXHAUSTED: Quota exceeded for aiplatform.googleapis.com/online_prediction_requests`.

**Fix:** 
- Zwiększ quotę przez Console: IAM & Admin → Quotas → wyszukaj "Vertex AI" → Edit.
- W Faza 2 default = 60 requests/min. Dla MVP wystarczy.

### Problem 3: Pub/Sub "delivery_attempt > max_delivery_attempts"

**Symptom:** Wiadomości lądują w DLQ (`audio.uploaded.dlq`).

**Fix:** Sprawdź logi worker'a:
```bash
gcloud functions logs read stt-worker --region=europe-central2 --limit=50
```
Najczęstsza przyczyna: timeout na BatchRecognize. Zwiększ `--timeout=900s`.

### Problem 4: pgvector "type vector does not exist" 

**Fix:** Włącz extension w connection (per-database):
```sql
CREATE EXTENSION IF NOT EXISTS vector;
```

### Problem 5: Flutter `record`: brak chunków

**Fix:** iOS wymaga `UIBackgroundModes` z `audio` w `Info.plist`. Bez tego app jest pauzowany w background po 30s.

### Problem 6: Cloud Function cold start > 30s

**Fix:** Dodaj `--min-instances=1` dla `stt-worker` i `llm-worker` na produkcji. Koszty: ~$15/mc per worker. Worth it dla UX.

### Problem 7: Gemini structured output "schema validation failed"

**Symptom:** Gemini zwraca JSON, który nie matchuje schema.

**Fix:** 
- Upewnij się że `response_mime_type` = `application/json`.
- Uprość schema (Gemini ignoruje unsupported fields).
- Niższa temperatura (0.1-0.3) daje bardziej kompliantne wyniki.

### Problem 8: Signed URL "403 Forbidden" na PUT

**Fix:** Sprawdź:
- Czy `Content-Type` w request matchuje `Content-Type` w SignedURLOptions.
- Czy `Content-MD5` jest poprawnie obliczony.
- Czy URL nie wygasł (30 min default).

---

## Pre-Faza 3 checklist

### Backend

- [ ] ingestion-svc deployowany, signed URLs działają.
- [ ] billing-svc stub deployowany, zwraca `allowed=true`.
- [ ] stt-worker Cloud Function reaguje na `audio.uploaded`.
- [ ] llm-worker Cloud Function reaguje na `transcript.completed`.
- [ ] Pipeline E2E: audio → transcript → report < 4 min dla 90s audio.

### Storage

- [ ] Bucket `superwizor-audio-uploads` z OLM 48h.
- [ ] CMEK enabled.
- [ ] Public access prevention.

### Pub/Sub

- [ ] 3 topics: `audio.uploaded`, `transcript.completed`, `report.generated`.
- [ ] DLQ skonfigurowane dla wszystkich subscriptions.
- [ ] Max delivery attempts = 5.

### Flutter

- [ ] Wakelock działa podczas nagrywania.
- [ ] Chunki rotowane co 30s.
- [ ] Upload przez signed URL z retry.
- [ ] Permissions iOS/Android skonfigurowane.

### Bezpieczeństwo

- [ ] Envelope encryption — placeholder w Fazie 2 (`ENCRYPT_PLACEHOLDER:` prefix).
- [ ] **TODO Faza 3:** Real Cloud KMS encryption dla `transcript_ciphertext`, `report_ciphertext`, `evidence_ciphertext`.
- [ ] All services `--no-allow-unauthenticated`.

### Observability

- [ ] Pipeline logs z `session_id` jako label.
- [ ] Cloud Trace pokazuje pełen pipeline od ingestion → llm-worker.
- [ ] Alert na DLQ (jakikolwiek message → email).

### Testing

- [ ] Test coverage ≥ 70% dla `ingestion-svc`, `billing-svc`, oba workers.
- [ ] E2E test passed dla 90s audio.

---

## Co zostało na Fazę 3

Faza 3 (Tygodnie 8-10) pokryje:

1. **Stripe integration** — pełna implementacja `billing-svc` z webhook handlerem.
2. **Envelope encryption** — zastąpienie placeholderów real Cloud KMS calls.
3. **HiTOP closed ontology** — finalna lista dimensions po konsultacji klinicznej.
4. **Speaker mapping UI** — frontend pozwalający korygować mapping przed re-analizą.
5. **Report viewer** — Flutter widok raportu z HiTOP visualization.
6. **report_feedback domain** — UI do zostawiania feedbacku (gwiazdki + kategorie).
7. **memory-compactor-worker** — agregacja `rag_memories` po > 50 chunkach per patient_file.
8. **Hardening** — rate limiting, circuit breakers, real RBAC w `clinical-svc.GetPatientFile`.

---

**🎉 Po Sprint 2.8 → ready dla Fazy 3 (Hardening + Stripe + UX).**
