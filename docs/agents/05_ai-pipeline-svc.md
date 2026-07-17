---
type: Backend Service Specification
title: "ai-pipeline-svc"
description: "The most critical service. Five workloads under one Go module: 1. stt-worker aka stt-submit (Cloud Functions Gen2) — Pub/Sub-triggered. Submits Chirp 3 Batch..."
resource: file:///Users/maciekckoklormam91/Desktop/Inne/APP%20-%20Superwizor%20AI/docs/agents/05_ai-pipeline-svc.md
tags: [svc, agents, pipeline]
timestamp: 2026-06-10T20:20:14+02:00
---

# ai-pipeline-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

The most critical service. Five workloads under one Go module:
1. **`stt-worker`** aka `stt-submit` (Cloud Functions Gen2) — Pub/Sub-triggered. Submits Chirp 3 BatchRecognize with `GcsOutputConfig`, INSERTs a row into `stt_operations`, and acks immediately. Does NOT wait for Chirp. Entry point: `ProcessAudio`.
2. **`stt-finalize`** (Cloud Functions Gen2; Stage 1 of feat/stt-long_audio_support, 2026-05-22) — Eventarc OBJECT_FINALIZE-triggered on `<project>-transcripts-raw` bucket. Reads Chirp's output JSON, runs `pkg/transcription/chunker`, persistTranscript (encrypted blob, ADR-IMPL-006), publishes `transcript.completed`. Shares the same source zip + SA as stt-worker (same package `sttworker`); entry point: `ProcessTranscriptObject`.
3. **`stt-watchdog`** (Cloud Functions Gen2 HTTP) — Cloud Scheduler-invoked every 15 min. Polls `stt_operations` rows older than 30 min with `finalized_at IS NULL`, asks Chirp's Operations API for status, and either drives finalize manually (DONE) or marks the session FAILED (ERROR). Belt-and-suspenders for dropped OBJECT_FINALIZE events. Shared source zip; entry point: `ProcessWatchdog`.
4. **`llm-worker`** (Cloud Functions Gen2) — Pub/Sub-triggered on `transcript.completed`. Loads transcript, runs LLM diarization + clinical analysis (Gemini 2.5 Flash-Lite today), persists report + HiTOP measurements, publishes `report.generated`. Branches at call-1 between "cluster + label" (no native speakers) and "label only" (native speakers from Chirp).
5. **`ai-pipeline-svc` Cloud Run service** — `/health` only since `feat/llm-optimisation`. Historical Gin worker stubs (`STTWorkerHandler` / `LLMWorkerHandler`) were dead code; removed.

## Status (2026-05-14)

- **Phase 2 — workers are the critical path.**
- `stt-worker` (Chirp 3 + chunker) — **DONE** for the no-native-diarization path. Language-aware STT + native-diarization-when-available branch is **IN PROGRESS** on `feat/llm-optimisation`.
- `llm-worker` (Gemini 2.5 Flash-Lite + LLM diarization + speaker label generation + HiTOP + risk + RAG-summary) — **DONE** for JSON-constrained call 1. Markdown call 1 (both grammars) + Format B transcript for call 2 + `LLM_DIARIZATION_MODE` flag is **IN PROGRESS** on `feat/llm-optimisation`.
- `ai-pipeline-svc` Cloud Run service — deployed, serves `/health` only.
- **memory-compactor-worker** (Phase 3 spec) — not built.

> Source for current behavior: `services/ai-pipeline-svc/cmd/{stt-worker,llm-worker}/main.go`. Source for spec: `docs/06_FAZA_2_INGESTION_AI.md` lines 1759–end + ADR-IMPL-001 through 007. Source for the LLM-optimisation refactor: this file (sections below marked **(feat/llm-optimisation)**) + the design plan in the conversation log on that branch.

> **Note on model**: the file historically said "Gemini 2.5 PRO". The production worker actually runs `gemini-2.5-flash-lite` (cheaper, what's available in `europe-west4`). PRO swap is queued as a separate change behind the Markdown rollout per the cost/quality eval.

## Repo paths

```
services/ai-pipeline-svc/
├── go.mod / go.sum
├── Dockerfile                        # /health Cloud Run service (cmd/server)
├── cmd/
│   ├── server/main.go               # Gin /health only (post feat/llm-optimisation)
│   ├── stt-worker/
│   │   ├── main.go                   # functions.CloudEvent("ProcessAudio", ...)
│   │   └── main_test.go
│   ├── llm-worker/
│   │   ├── main.go                   # functions.CloudEvent("ProcessTranscript", ...)
│   │   └── schemas/report_schema.json # JSON schema (kept for fallback / json-mode flag)
│   └── llm-eval/                    # Offline matrix evaluator (manual runs)
└── internal/
    ├── adapters/
    │   ├── postgres/db/             # sqlc-generated
    │   ├── pubsub/publisher.go      # uses pubsub/v2
    │   └── ...
    ├── transcriptfmt/               # (feat/llm-optimisation) NEW
    │   ├── markdown.go              # FormatChunkIndexed + FormatSpeakerTurns + BCP47 helper
    │   └── markdown_test.go
    ├── diarization/                 # (feat/llm-optimisation) NEW
    │   ├── markdown.go              # Markdown parser, both grammars (cluster + role-only)
    │   └── markdown_test.go
    ├── reportprefs/                 # (feat/report-customization, 2026-05-18) NEW
    │   ├── reportprefs.go           # Preferences struct + RenderFragment + MaxOutputTokens + TargetLengthDirective
    │   └── reportprefs_test.go
    └── models/, services/

pkg/transcription/chunker/           # ChunkByPauses, used by stt-worker
pkg/i18n/speakerlabels/              # Generate(langCode, tag) → "Osoba 1" etc.
pkg/cryptobox/                       # envelope encryption
```

**Critical:** `cmd/stt-worker/main.go` is `package sttworker`, `cmd/llm-worker/main.go` is `package llmworker`. **Do NOT add `func main()`** — they're Cloud Functions Gen2; the framework provides the entry point. `golangci-lint`'s `unused` linter flags any `main()` here.

## Pipeline flow

```
Flutter CreateAudioUpload → ingestion-svc creates session row in
  PENDING_UPLOAD status, copies patient_user.ui_language →
  session.language_code (BCP47-ized), returns session_id + signed URL.
       ↓
Flutter PUT to GCS (via signed URL). Client terminates here —
  phase=completed on the Hive queue, no follow-up RPC.
       ↓
GCS bucket notification on audio-uploads fires audio.objectFinalized topic.
ingestion-svc's in-process subscriber (Option F, 2026-05-25) consumes:
  - probes ffprobe duration (authoritative)
  - fallback-transcodes to FLAC if source is not Chirp-supported
  - on long audio (> 1140 s): ffmpeg silence-detect + write audio_chunks rows
  - flips sessions.status PENDING_UPLOAD → CREATED
  - calls PublishAudioUploaded({session_id, upload_id, object_path})
       ↓
Pub/Sub topic audio.uploaded   (ingestion-svc is the sole publisher;
  it emits the structured payload stt-worker expects. The bucket
  notification routes to audio.objectFinalized, NOT this topic.)
       ↓
stt-submit (ProcessAudio, refactored 2026-05-22 in feat/stt-long_audio_support):
  1. update sessions.status = TRANSCRIBING
  2. lang := session.language_code (from ingestion-svc patient-user copy)
  3. nativeDiarize := operator opt-in AND chirp3DiarizationLanguages[lang]
  4. Pre-flight SELECT chunk_index FROM stt_operations WHERE session_id = $1
       — lets a redelivery skip already-submitted chunks
  5. For each chunk plan (Stage 1: always one virtual chunk; Stage 2
     will read audio_chunks rows after server-side ffmpeg split):
       a. submitBatchRecognize(gcsURI, outputPrefix=
            gs://transcripts-raw/{sid}/chunk_{i}/, lang, nativeDiarize)
            → Chirp 3 BatchRecognize, eu-speech endpoint
            → GcsOutputConfig.Uri = outputPrefix (NO op.Wait)
            → returns operation_name (Chirp processes async)
       b. INSERT INTO stt_operations (...) — UNIQUE on
            (session_id, chunk_index); 23505 races silently dropped
  6. ACK Pub/Sub (return nil)
       ↓
   Chirp does its work async (1-30 min). When it finishes it writes
   `transcript_{op_hash}.json` to the prefix configured above.
       ↓
GCS OBJECT_FINALIZE on transcripts-raw → Eventarc → stt-finalize
       ↓
stt-finalize (ProcessTranscriptObject):
  1. ParseOutputObjectPath(object_name) → (session_id, chunk_index).
     Sidecar metadata files / unrelated uploads: silently skip.
  2. UPDATE stt_operations SET finalized_at = now()
       WHERE (session_id, chunk_index) AND finalized_at IS NULL
       — 0 rows affected (Pub/Sub redelivery) → ack and return
  3. countPendingChunks(session_id) > 0 → ack (waiting on siblings)
  4. acquireMergeLock(): SELECT status FROM sessions FOR UPDATE.
       If TRANSCRIBING → flip to MERGING. Else (already merged /
       failed) → ack. Only one finalize invocation wins the lock.
  5. loadOperationsForSession → for each chunk:
       a. List GCS prefix → find transcript_*.json
       b. protojson.Unmarshal into speechpb.BatchRecognizeResponse
       c. ParseChirp3Results (unchanged) — propagates file-level
          Chirp errors via the "chirp 3 returned" prefix that
          isTerminalSTTError already catches
       d. fillSpeakerLabels (ADR-IMPL-007a sparse-label recovery,
          per chunk, before merge)
  6. sttgcs.MergeChirpResults(parts) — Stage 1 single-chunk passthrough;
     Stage 2 will overlay time-anchored cross-chunk label alignment
  7. chunker.ChunkByPauses(words, DefaultConfig{600ms, 300ms, 60s})
  8. persistTranscript: encrypt blob → transcripts row +
       transcript_segments. On 23505 against
       transcripts(session_id) UNIQUE (migration 000021) →
       fetch the existing row's id and continue. Recovers from a
       prior attempt that committed transcripts but crashed before
       publishTranscriptCompleted.
  9. update sessions.status = ANALYZING
 10. publishTranscriptCompleted on transcript.completed
 11. ACK

  On error in mergeAndPersist (deferred handler):
    - Terminal (Chirp file-level error / codec rejection): mark
      sessions.status = FAILED, record finalize_error on the chunk
      row. The session is dead.
    - Transient (DB / KMS / GCS 5xx / unknown): revert
      sessions.status = TRANSCRIBING. Pub/Sub will redeliver the
      OBJECT_FINALIZE event (or the watchdog will rescue); the
      idempotent `finalized_at IS NULL` guard makes that safe.

  Without the revert, a transient failure mid-merge would leave the
  session in MERGING forever — the status guard in acquireMergeLock
  would never let any worker re-enter.

stt-watchdog (ProcessWatchdog, HTTP, Cloud Scheduler */15 min):
  - SELECT * FROM stt_operations WHERE submitted_at < now()-30min
       AND finalized_at IS NULL
  - For each row: speechClient.BatchRecognizeOperation(op.OperationID).Poll
       - Pending → log + leave alone
       - Error → record_finalize_error, mark session FAILED
       - Done → drive finalize manually (markChunkFinalized +
              finalizeIfReady)
  - Returns 200 unconditionally (Cloud Scheduler non-2xx retry is
    redundant with the next-tick scan)
       ↓
Pub/Sub transcript.completed
       ↓
llm-worker (ProcessTranscript):
  1. load SessionContext (sessions row + speaker_label_mapping +
       therapist_id + users.report_preferences via patient_files JOIN)
  2. loadTranscriptBlob: decrypt → []BlobLine
  3. hasNativeSpeakers := any(BlobLine.speaker_tag != 0)
  4. loadRAGContext (real, since 2026-05-19):
       a. embed currentText via text-embedding-005 (768-dim)
       b. pgvector cosine search, 2-stage CTE:
            stage 1: patient's last 36 rag_memories rows (most-recent
                     first, NOT is_compacted)
            stage 2: top-3 by cosine distance within that pool
       c. decrypt summary_ciphertext (KMS envelope), skip empties
       d. join with double-newline, cap at 5000 chars total
       e. background UPDATE last_accessed_at (best-effort)
       Non-fatal on every error: returns "" + nil, worker continues.
       Result threaded into call-2 ONLY (not call-1) — see RAG
       section below for rationale.
  5. loadModalityPrompt (from modalities.therapist_ai_general_prompt JSONB —
     row seeded by add_modality.py, see docs/12_ADDING_NEW_MODALITY.md)
  6. Call 1 (metadata + diarization):
       a. transcript text:
            - hasNativeSpeakers → Format B (## Speaker N [00:01.20 – ...])
            - else              → Format A (## Chunk N [00:01.20])
       b. prompt:
            - hasNativeSpeakers → "infer role per speaker_tag" (short)
            - else              → "cluster chunks + infer roles" (full)
       c. output mode:
            - LLM_DIARIZATION_MODE=markdown → text/plain, parser handles both grammars
            - LLM_DIARIZATION_MODE=json     → schema-constrained (legacy path)
       d. parse → SpeakerRoleInference (same struct shape on every branch)
       config: metadataGenConfigJSON / metadataGenConfigMarkdown helpers
  7. generateAndSaveSpeakerLabels:
       walk SpeakerGroups → assign sequential speaker_tags (skip filler/unknown)
       speakerlabels.Generate(langCode, tag)
       update transcript_segments + sessions.speaker_label_mapping
  8. Call 2 (clinical report):
       transcript text: always Format B (speaker-turn Markdown, labels now resolved)
       prompt: modality baseline
               + reportprefs.RenderFragment(prefs)  ← preferences fragment
               + reportprefs.TargetLengthDirective(prefs)  ← length directive
               + ZASADY ZWIĘZŁOŚCI + RAG + transcript
       config: reportGenConfig(reportprefs.MaxOutputTokens(prefs))
       safety: retry once at 2× cap on FinishReasonMaxTokens
       Markdown text output
  9. persistReport: encrypt → therapist_reports + hitop_measurements
 10. update sessions.status = COMPLETED
 11. publishReportGenerated on report.generated
 12. ACK Pub/Sub
       ↓
notification-svc (Phase 3) → FCM push to therapist
```

## Transcript format for LLM input (feat/llm-optimisation)

Two markdown shapes; choice driven by whether speaker tags arrived from Chirp 3 (or are still 0):

| Format | When used | Why this shape |
|---|---|---|
| **A — chunk-indexed** | Call 1 *without* native speakers (LLM has to cluster) | LLM output references chunks by index: `Group 1 — therapist; Chunks: 0,2,5`. So chunk indices must be visible. |
| **B — speaker-turn-grouped** | Call 1 *with* native speakers; **every call 2** | Speakers already exist; LLM does NOT need chunk granularity. Cleaner prose, ~30% fewer tokens, better narrative quality on call 2. |

Format A example (Polish, individual):
```markdown
## Chunk 0 [00:01.20]
Z czym dzisiaj przychodzisz?

## Chunk 1 [00:04.80]
Co cię trapi?

## Chunk 2 [00:08.00]
Trochę zmęczona ostatnio.
```

Format B example (Polish, after diarization resolved):
```markdown
## Speaker 1 [00:01.20 – 00:07.30]
Z czym dzisiaj przychodzisz? Co cię trapi?

## Speaker 2 [00:08.00 – 00:12.45]
Trochę zmęczona ostatnio.
```

Both formats produced by `services/ai-pipeline-svc/internal/transcriptfmt/markdown.go`.

## LLM output format for call 1 (feat/llm-optimisation)

Flag: `LLM_DIARIZATION_MODE ∈ {json, markdown}`. Default `json` (legacy schema-constrained) until probe passes; flipped to `markdown` after staging validation.

**Markdown mode, cluster grammar** (no native speakers — produced by Format A input):
```markdown
# Speakers
## Group 1 — therapist (confidence 0.87)
Chunks: 0, 2, 5, 8
Evidence: "Z czym dzisiaj przychodzisz?"

## Group 2 — patient (confidence 0.92)
Chunks: 1, 3, 6, 9
Evidence: "Trochę zmęczona ostatnio."

# Metadata
Title: Pierwsza sesja - bezsenność
Summary: Pacjentka zgłasza ...
Overall_diarization_confidence: 0.89
```

**Markdown mode, role-only grammar** (native speakers — produced by Format B input):
```markdown
# Speakers
Speaker 1 — therapist (confidence 0.92)
Speaker 2 — patient (confidence 0.95)

# Metadata
Title: ...
Summary: ...
Overall_diarization_confidence: 0.94
```

Both grammars parsed by `internal/diarization/markdown.go` into the same `SpeakerRoleInference` Go struct (cluster grammar fills `ChunkIndices`; role-only grammar fills `ChunkIndices` post-hoc by walking the transcript and grouping by the existing `speaker_tag`).

**JSON mode** (legacy) — unchanged. Same `report_schema.json` constrained output, same parsing path.

## Speaker label generation (role-aware, 2026-05-25)

Migration 000026 added `modalities.modality_type ∈ {therapy, coaching}`,
backfilled by `system_code` (`COACH` → coaching, everything else
→ therapy). `loadSession` in llm-worker JOINs that column into
`SessionContext.ModalityType`. `generateAndSaveSpeakerLabels` walks
the LLM's `SpeakerRoleInference.SpeakerGroups` in insertion order
and calls `pkg/i18n/rolelabels.Generate(langCode, modality, role,
tag, takenRoles)` per group.

| modality | role_hint | 1st speaker (pl-PL / en-US) | 2nd+ (collision) |
|---|---|---|---|
| therapy | therapist | Terapeuta / Therapist | Terapeuta 2 / Therapist 2 |
| therapy | patient | Pacjent / Patient | Pacjent 2 / Patient 2 |
| coaching | therapist | Trener / Coach | Trener 2 / Coach 2 |
| coaching | patient | Klient / Client | Klient 2 / Client 2 |
| any | couple_partner / family_member_* / third_party / unknown / filler | falls through to `speakerlabels.Generate` → "Osoba N" / "Person N" | (numeric only) |

Counters for `therapist` and `patient` are independent: a
therapy session with one therapist + two patients produces
`{1: "Terapeuta", 2: "Pacjent", 3: "Pacjent 2"}`, NOT `Pacjent 3`.

The LLM's role vocabulary is unchanged — `therapist` and
`patient` remain the canonical "professional" and "client" slots
regardless of modality. The coaching reinterpretation happens
purely at render time, which avoids touching the prompt templates
or the diarization grammar.

Localizations live in `pkg/i18n/rolelabels/rolelabels.go`'s `vocab`
table. Adding a new language: add an entry under each
`<modality>|<role>` key. Missing entries fall through to English.

## Constraining ADRs (this service is the densest)

| ADR | What it forces |
|---|---|
| **ADR-IMPL-001** | Chirp 3 (NOT Chirp 2); `eu-speech.googleapis.com` endpoint for EU residency |
| **ADR-IMPL-002** (amended 2026-05-25) | Speaker labels are localized. Role-aware labels are now allowed in storage: `pkg/i18n/rolelabels.Generate` produces "Terapeuta"/"Pacjent" (therapy) or "Trener"/"Klient" (coaching) for dyadic role hints (`therapist`, `patient`) based on `modalities.modality_type` (migration 000026). Non-dyadic roles (`couple_partner`, `family_member_*`, `third_party`, `unknown`, `filler`) fall through to the legacy neutral helper `pkg/i18n/speakerlabels.Generate` → "Osoba N" / "Person N". Numeric suffix on collisions ("Pacjent 2"). The original prohibition on hardcoded English labels still stands — always localize. |
| **ADR-IMPL-003** | Gemini via Vertex AI (not the public Gemini API). Model: `gemini-2.5-flash-lite` today; structured outputs via `response_schema` (JSON mode) OR Markdown + server-side parse (Markdown mode, behind `LLM_DIARIZATION_MODE` flag). Model swap (Flash, Pro, 3.x) is a separate change behind the Markdown rollout. |
| **ADR-IMPL-004** | Workers are Cloud Functions Gen2, not Cloud Run services. Don't add `main()`. |
| **ADR-IMPL-006** | `transcripts.transcript_ciphertext` is the **canonical blob**. Segments are derived. Any rebuild path (e.g., clinical-svc `UpdateSpeakerLabels`) must rebuild this blob. |
| **ADR-IMPL-007** | Originally: `pl-PL` doesn't have native Chirp 3 diarization; LLM clusters. Generalized in `feat/llm-optimisation`: per-language gate via static `chirp3DiarizationLanguages` map; **`pl-PL` stays false** until verified on staging. Each language flips independently with evidence. When false → LLM-clusters path (current behavior). When true → STT native tags + LLM only labels roles. Same downstream `SpeakerRoleInference` struct in both branches. |
| **ADR-IMPL-007a** | Chirp 3 native diarization labels are **sparse, not complete**: the dominant speaker is labeled reliably, the other speaker's words and filler often come back with `label=""`. We treat this as a known characteristic and recover via two layers: `stt-worker.fillSpeakerLabels` propagates labels within continuous speech (bounded by pause threshold); `llm-worker.markdownResultToPayload` reattaches orphan `SpeakerTag=0` chunks to the LLM's single empty `SpeakerGroup` when exactly one is empty. See the "Native-diarization sparse-label recovery" section above. |
| **P1 (Zero Data Loss)** | Idempotency: `SELECT status FROM sessions WHERE id=$1 FOR UPDATE SKIP LOCKED` at worker entry. If status already advanced, ACK without work. |
| **P3 (EU residency)** | Vertex AI region `europe-west4`; STT endpoint `eu-speech.googleapis.com:443` |

## The chunker (`pkg/transcription/chunker`)

Pause-threshold-based segmentation. `DefaultConfig`:
- `PauseThresholdMS: 600` — split when gap between word `end_ms` and next word `start_ms` ≥ 600ms.
- `MinChunkDurationMS: 300` — merge tiny chunks (< 300ms) into neighbors.
- `MaxChunkDurationMS: 60000` — split chunks longer than 60s.

Pipeline: `buildBaseChunks` → `mergeShortChunks` → `splitLongChunks`. See [`pkg/transcription/chunker/chunker.go`](../../superwizor-backend/pkg/transcription/chunker/chunker.go).

If you change defaults, update `DefaultConfig` and re-run the test in `chunker_test.go`. The thresholds are tuned for Polish therapy speech — changing them affects diarization quality downstream.

## Report customization integration (feat/report-customization, 2026-05-18)

Per-therapist report style preferences. **identity-svc owns the
storage** (`users.report_preferences JSONB`); ai-pipeline-svc is the
**sole consumer** at call-2 prompt build time. Rating feedback +
suggestion engine live in clinical-svc.

Design spec: `docs/10_REPORT_CUSTOMIZATION.md`.

### Loading

`loadSessionContext` in `cmd/llm-worker/main.go` was extended with a
JOIN through `patient_files → users.report_preferences`. New fields
on `SessionContext`:

```go
type SessionContext struct {
    ...
    TherapistID       uuid.UUID                     // NEW
    ReportPreferences reportprefs.Preferences       // NEW (zero value = use defaults)
}
```

The JOIN uses `COALESCE(u.report_preferences, '{}'::jsonb)` so a
NULL row (shouldn't happen post-migration 000015) decodes as
default. A corrupt JSONB blob is logged as Warn and falls through
to defaults — never fails the whole pipeline.

### Rendering

`internal/reportprefs/RenderFragment(prefs)` produces a Polish
prompt block subordinate to the modality baseline:

```
PREFERENCJE TERAPEUTY (uzupełnienia stylu, NIE sprzeczne z
powyższymi zasadami klinicznymi):

- Długość raportu: krótki (≈1 strona)
- Ton: empatyczny-ciepły
- Cytaty z transkryptu: wybiórczo (3-5)
- ...
- Dodatkowe wskazówki terapeuty: <free_text verbatim>
```

Empty / all-defaults / unknown-enum input → empty fragment.
Preserves byte-identical prompts for users who haven't configured.
Inserted in `generateReport` **between** the modality prompt
(immutable clinical framework) and the universal `ZASADY ZWIĘZŁOŚCI`
block — the "NIE sprzeczne" framing keeps the modality baseline
winning on any conflict.

### Length caps + prompt directive (2026-05-18 calibration)

Pre-feature observation: reports were verbose even for 2-min sessions because `MaxOutputTokens` was 65535 (effectively uncapped) and the model fills available room.

**New constants** in `cmd/llm-worker/main.go` (Polish token math:
~600 tok/page, 7 sections × 2-5 sentences each per ZASADY ZWIĘZŁOŚCI):

| Constant | Value | Notes |
|---|---|---|
| `geminiTempMetadata` | 0.1 | Call 1 (parser-friendly) |
| `geminiTempReport` | 0.2 | Was 0.3 — accuracy > prose variety |
| `geminiTopP` | 0.95 | Shared |
| `geminiMaxOutMetadata` | 2048 | Call 1 JSON/Markdown — was 16384 |
| `geminiMaxOutReportDefault` | 4096 | Call 2 standard target — was 65535 |
| `geminiMaxOutReportHardCeiling` | 65535 | Vertex's hard limit; used only by safety retry |

**`reportprefs.MaxOutputTokens`** maps the therapist's `length` preference to a cap:
- `brief` → 2048 (~1-page report, 3× safety margin over 600 effective tokens)
- `standard` → 0 (caller's `geminiMaxOutReportDefault` applies)
- `detailed` → 8192 (~3-page report, 4× safety margin)

**`reportprefs.TargetLengthDirective`** returns the prompt directive paired with the cap:

```
DOCELOWA DŁUGOŚĆ RAPORTU: ~2 strony (≈1000 słów).
Mieść się w tym budżecie z marginesem na zwięzłą formę.
```

Inserted as a standalone block above `ZASADY ZWIĘZŁOŚCI`. **The model honors prompt budgets much better than implicit `MaxOutputTokens` caps** — pair them; don't rely on either alone.

### Safety-retry pattern (rollout period only)

After call 2 returns, if `FinishReason == FinishReasonMaxTokens`,
`generateReport` retries ONCE at 2× cap (bounded by
`geminiMaxOutReportHardCeiling`). Logs `Warn` on retry, `Error` if
retry also truncates (accepts the partial output rather than loop).

**Belt-and-suspenders for the new caps.** Tracked in
`docs/agents/TODO.md` — once production data shows trigger rate <1%
over 2 weeks, the retry block is the first thing to drop (~20 lines).

Cloud Logging filter for monitoring:
```
resource.labels.service_name="llm-worker"
AND (jsonPayload.message=~"MaxOutputTokens")
```

### Constraints when editing this surface

- **Add a new preference dimension**: update `Preferences` struct here AND `preferencesPayload` in identity-svc.preferences.go AND the validator allow-lists there AND the label maps here AND the chip mapping in clinical-svc.ratings.go (if it has a complaint chip). Five places, one PR. Doc-commented at the top of `reportprefs.go`.
- **Tighten caps further**: only after monitoring shows zero MaxOutputTokens retries. The math currently assumes ~600 tok/page for Polish; if you switch the audio language to one with different tokenization density (English ~400 tok/page, Mandarin ~1500 tok/page) the page-count math breaks. Verify with `cmd/llm-eval` first.
- **Never override the modality prompt** from preferences. The fragment is subordinate by design (P4 + ADR-IMPL-007); inverting that lets a therapist disable safety/risk emphasis, which is the one thing we won't expose as a knob (intentionally dropped from the design — see `docs/10_REPORT_CUSTOMIZATION.md` §13.1).

### GenerationConfig helper functions

Three helpers in `cmd/llm-worker/main.go` consolidate the three call profiles into single source-of-truth blocks:

| Helper | Used by | Output shape |
|---|---|---|
| `metadataGenConfigJSON(schema)` | `callMetadataJSON` | Temp 0.1, TopP 0.95, MaxOut 2048, `application/json` + `ResponseSchema` |
| `metadataGenConfigMarkdown()` | `callMetadataMarkdown` | Same temp/TopP/MaxOut, no MIME/schema |
| `reportGenConfig(maxOut int32)` | `generateReport` | Temp 0.2, TopP 0.95, `text/plain`, MaxOut from arg (falls back to `geminiMaxOutReportDefault` when 0) |

Don't inline new `genai.GenerateContentConfig{...}` literals at call sites — pollute the lockstep.

**Cap-vs-target bump (2026-05-19):** caps decoupled from the prompt-directive target. The `TargetLengthDirective` is what shapes report length; the cap is a remote safety net. Old approach (cap = target) silently truncated 10–20% overshoots and triggered an expensive safety-retry (~3× cost on affected sessions). New defaults give 3× headroom over the directive target:

- `geminiMaxOutReportDefault`: 4096 → **12288** (standard length)
- `reportprefs.MaxOutputTokens(brief)`: 2048 → **6144**
- `reportprefs.MaxOutputTokens(detailed)`: 8192 → **24576**
- Soft section_emphasis ceiling: **32768** (still well below `geminiMaxOutReportHardCeiling=65535`)

Plus `section_emphasis` budget scaling: each emphasized section adds 500 tok of cap headroom (`MaxOutputTokens(prefs) += n * 500`). Reason: emphasized sections are a prompt nudge to expand, which costs tokens. Without the bump, the production session `0a5523a0` (standard + 7 emphasized sections) hit cap → safety-retry → hit cap AGAIN → accepted truncated output.

**Safety-retry multiplier 2× → 4×** (also 2026-05-19). With 3× default headroom, the safety-retry should essentially never fire — but if it does, 2× cap occasionally re-triggers (observed: session `0a5523a0`, both calls truncated). 4× gives the retry real budget. Cap clamped at `geminiMaxOutReportHardCeiling=65535`.

**Markdown blockquote enforcement** (also 2026-05-19): call-2 prompt explicitly forbids label-form quotes (`**Cytat:** "..."`, `**Quote:** "..."`) and requires `> "..."` on its own line. The Flutter rendering layer only styles `> ` blockquotes — label-form quotes lost their visual treatment and read as plain text. Even when the modality template suggests a label form, the call-2 prompt overrides.

**SDK migration (2026-05-19):** the worker was migrated from `cloud.google.com/go/vertexai/genai` (deprecated 2025-06-24, removed 2026-06-24) to `google.golang.org/genai`. Three structural deltas to remember when touching the call sites:

1. **No per-model object.** The old pattern `model := client.GenerativeModel(name); model.GenerationConfig = cfg; model.GenerateContent(...)` no longer exists. Each call is `vertexClient.Models.GenerateContent(ctx, modelName, contents, cfg)` with the config passed as the fourth argument.
2. **Config type is `*genai.GenerateContentConfig` (pointer).** The three helpers in this file return pointers, not value types.
3. **Parts are structs, not interfaces.** Read `part.Text` directly instead of `if t, ok := part.(genai.Text); ok`. The old type assertion no longer compiles.

`genai.Text`, `genai.Ptr`, `genai.Schema`, the `genai.Type*` enums, `genai.FinishReasonMaxTokens`, and the response-shape (`Candidates[...].Content.Parts`, `UsageMetadata.PromptTokenCount`, `UsageMetadata.CandidatesTokenCount`) are unchanged.

## Native-diarization sparse-label recovery (2026-05-15)

Chirp 3's native diarization is **not** "every word gets a speaker_label". In practice it labels the dominant speaker reliably and drops labels on the other speaker's words (and on short interjections / filler). On session `26ecf316` we observed: 295 words, 8 chunks correctly `tag=1` (~195 words, therapist), 12 chunks interleaved at the patient's timestamps stuck at `tag=0, label=""` (~100 words). The LLM call-1 still inferred two speakers from content, but `markdownResultToPayload` found zero chunks with `SpeakerTag=2` → patient `SpeakerGroup.ChunkIndices=null` → `generateAndSaveSpeakerLabels` never wrote `tag=2` rows → UI rendered "Person 1" only.

Two-layer mitigation. Both stay enabled whenever `useNativeDiarization=true`:

**Layer 1 (signal-level, stt-worker)** — `fillSpeakerLabels(words, maxGapMS)` runs between `transcribeAudio` and `chunker.ChunkByPauses`. Forward pass: propagates the most recently-seen non-empty `SpeakerLabel` into adjacent unlabeled words. Backward pass: same for leading unlabeled words (Chirp's first label appears later in the stream). **Both bounded by `chunker.DefaultConfig().PauseThresholdMS` (600ms)** — pauses are our only signal that the speaker may have changed, so we never propagate across them. Mutates the word slice in place.

**Layer 2 (defensive, llm-worker)** — in `markdownResultToPayload(native=true)`, after collecting chunks per LLM-inferred speaker: if **exactly one** `SpeakerGroup` ended up with zero `ChunkIndices` AND there are `SpeakerTag=0` orphan chunks, give all orphans to the empty group. The LLM saw the transcript content and concluded N speakers exist; a single empty group is the "Chirp only labeled the other speaker" case. **Multiple** empty groups → log a warning, skip — we don't have enough signal to guess which orphan goes where.

Trade-offs:
- Layer 1 can mis-attribute if Chirp labels only one speaker AND the unlabeled run is genuinely the other speaker without a pause between them. We accept this — the pause boundary is the strongest signal we have. If Chirp's labeling reliability ever degrades further, the fallback is to disable native diarization for that language in `transcriptfmt.Chirp3DiarizationLanguages`.
- Layer 2 assumes the LLM doesn't hallucinate a missing speaker. The role-only prompt forces the LLM to label only the speakers visible in Format B input; if it adds a speaker that isn't in the transcript, that's a different bug (we'd see hallucinated text in the report too).

Tests: `TestFillSpeakerLabels` in `services/ai-pipeline-svc/cmd/stt-worker/main_test.go` covers forward fill, pause-boundary stop, backward fill, all-unlabeled no-op, all-labeled invariant, empty input, and the session-26ecf316 shape. Run with `go test ./services/ai-pipeline-svc/cmd/stt-worker/...`.

## Long-term memory (RAG) — theme-level v2 (2026-06-10, docs/30)

The worker accrues an identity-stripped summary **plus 2–5 theme entries**
per session into `rag_memories`, and on the next session retrieves the
prior threads most relevant to THAT session's own themes. Replaces the
2026-05-19 whole-session-summary design; the old reader and the
`LLM_RAG_MODE` flag were removed outright (pre-GA, no rollback path).
Design + decisions: `docs/30_RAG_THEME_CONTEXT_REFACTOR.md`.

### Pipeline order (the key change)

```
ProcessTranscript
  ├─ generateMetadata        (call-1: diarization + Title/Summary +
  │                           RAG_Summary + 2–5 RAG_Theme lines.
  │                           Still receives NO prior context — see
  │                           "Why call-1 doesn't get RAG" below.)
  ├─ loadRAGContextV2        (query = THIS session's themes)
  ├─ generateReportBody      (call-2: report + KONTEKST POPRZEDNICH SESJI)
  ├─ persistReport
  └─ persistRAGMemoryV2      (1 'summary' row + N 'theme' rows,
                              embeddings in parallel, one txn)
```

Call-1 → retrieve → call-2 ordering exists because call-1's output IS the
retrieval query. The old design embedded the raw transcript as the query —
text-embedding-005 caps input at ~2 048 tokens and silently truncates, so
on long sessions the query vector represented only the opening ~10 minutes.

### Write side (`persistRAGMemoryV2`, main.go)

- Row 1: `chunk_type='summary'`, importance 0.7 — doubles as the
  previous-session **anchor** and the themeless fallback.
- Rows 2..N: `chunk_type='theme'`, importance 0.5 — one per distinct
  `RAG_Theme:` line from call-1 (markdown grammar: repeated-prefix lines,
  parsed tolerantly in internal/diarization — absent block → empty slice,
  capped at 5, each ≤400 chars; JSON mode: `rag_themes` array).
- All embeddings concurrent (errgroup ≤6), inserts transactional,
  whole step best-effort (Warn, never fails the report).
- No schema migration — `chunk_type VARCHAR(50)` already supported it.

### Read side (`loadRAGContextV2` + helpers, main.go; ranking in rag.go)

1. **Pool** (`loadRAGPool`): every non-compacted row from the patient's
   most-recent **36 sessions** (session-based CTE on DISTINCT
   source_session_id; row-based lookback died with the old reader),
   current session excluded (fixes a redelivery self-retrieval bug).
   Embeddings only — nothing decrypted during ranking.
2. **Queries**: one embedding per call-1 theme; fallbacks: RAG_Summary →
   transcript head+tail (1 000 chars each side, the <2-chunk case).
3. **Rank** (`selectRAGHits`, pure Go, unit-tested in rag_test.go):
   - anchor = most recent prior session's summary row, ALWAYS selected;
   - score = max cosine over theme vectors × (0.7 + 0.3·recency),
     recency half-life 90 d;
   - greedy fill with per-session cap (2) + near-dup gate (cosine > 0.92
     vs already-selected) + positive-score requirement (legacy
     zero-vector rows score 0 and never surface);
   - ≤6 hits total (`ragMaxHits`).
4. **Assemble** (`assembleRAGContext`): decrypt winners only (1 KMS call
   per winner, never per pool row), group by session with dates —
   `[Poprzednia sesja — 2026-06-03]` / `[Sesja z 2026-05-12 — powiązane
   wątki]` — globally numbered, capped at 8 000 chars (anchor never
   trimmed).
5. `last_accessed_at` bumped in a background goroutine (best-effort).

### Why call-1 doesn't get RAG (2026-05-19, still binding)

All call-1 outputs are structural facts about THIS session. Injecting
prior context produced: ordinal titles ("Druga sesja…"), summaries that
referenced prior content, duplicate-content multiplication in RAG entries,
and role-label bias. The self-containment ZASADY lines in both call-1
grammars enforce this; `RAG_Theme` carries the same no-PII, this-session-
only instructions.

### Knobs (rag.go)

| Constant | Default | Why |
|---|---|---|
| `ragLookbackSessions` | 36 | session-based candidate pool (≈9 mo weekly) |
| `ragMaxHits` | 6 | 1 anchor + ≤5 semantic hits |
| `ragPerSessionCap` | 2 | one chatty session can't crowd the block |
| `ragDupSimThreshold` | 0.92 | MMR near-duplicate gate |
| `ragRecencyHalfLifeDays` | 90 | decay half-life |
| `ragRecencyFloor` | 0.7 | recency tunes ordering, never dominates |
| `ragContextMaxCharsV2` | 8000 | ≈4 k tok, <10 % of call-2 input |
| `embeddingModel/Dims` | text-embedding-005 / 768 | matches `vector(768)` (main.go) |

### Failure modes (all non-fatal, unchanged contract)

Query/theme embedding fails → context `""`, report proceeds. One row's
KMS decrypt fails → skip row. persistRAGMemoryV2 fails → Warn, report
already saved. Empty pool (first session) → `""`, no analytics event.

### Observability

`rag.retrieved` analytics event (only when hits exist): `mode=v2`,
`pool_size`, `themes_count`, `hits`, `memories_used`,
`sessions_represented`, `anchor_used`, `context_chars`.

Verified in prod 2026-06-10 via `TestFullSession_RAGTwoSessions`
(tests/e2e/rag_context_test.go — two sessions, one patient): session 2
logged `pool_size=3 themes_count=2 hits=2 anchor_used=true
context_chars=411`.

### Privacy

Unchanged: `patient_file_id` scoping (partial index), KMS envelope on
every stored plaintext (theme rows included), no-PII prompt instructions
on RAG_Summary AND RAG_Theme, `ON DELETE CASCADE` from patient_files
wipes the whole memory. Pool fetch reads embeddings only.

## The LLM diarization prompt (Phase 2 critical path)

`llm-worker` loads `modalities.therapist_ai_general_prompt` (JSONB) per session's modality. The prompt instructs Gemini to:
1. **(Call 1 / cluster grammar only)** Cluster chunks into speakers (`SpeakerRoleInference.SpeakerGroups[].ChunkIndices`).
2. Deduce roles (therapist / patient / couple_partner / family_member_* / third_party / unknown / filler).
3. **(Call 2)** Produce the full clinical report from the resolved speaker turns.

Two call-1 contracts coexist behind `LLM_DIARIZATION_MODE`:
- **JSON mode** (legacy): `services/ai-pipeline-svc/cmd/llm-worker/schemas/report_schema.json` drives Vertex's structured-output constraint. **If you change the schema, also update `ReportPayload` Go struct in `llm-worker/main.go` AND any consumers in clinical-svc.**
- **Markdown mode** (new): no schema; LLM emits the format documented above; parsed by `internal/diarization/markdown.go`. Schema file is kept for the JSON-mode fallback + the offline eval matrix.

> Research backing the Markdown move (Tam et al., 2024 "Let Me Speak Freely?"): JSON-constrained decoding costs ~10–15% on reasoning tasks; smaller models lose the most. Diarization clustering is a reasoning task. The 3-session probe on `feat/llm-optimisation` validates per-model before the flag flips.

> See `docs/06_FAZA_2_INGESTION_AI.md` ADR-IMPL-007 (lines 245–379) for the full diarization design + UX.

Migration `000008_modality_prompts_pl.up.sql` populates the Polish prompts. If prompt content changes, write a new migration — don't UPDATE in place outside migrations.

## Tables touched

| Table | Read | Write |
|---|---|---|
| `sessions` | yes (status, speaker_label_mapping, language_code) | yes (status updates, language, speaker_label_mapping) |
| `transcripts` | yes (read blob in llm-worker) | yes (insert in stt-worker) |
| `transcript_segments` | yes (read for label rebuild path) | yes (insert in stt-worker; update labels in llm-worker) |
| `therapist_reports` | — | yes (insert in llm-worker) |
| `hitop_measurements` | — | yes (insert in llm-worker) |
| `modalities` | yes (read prompt JSON) | — |
| `audio_uploads` | yes (status check) | yes (status update on success) |
| `stt_operations` | yes (stt-finalize merger + stt-watchdog scan) | yes (insert in stt-submit, finalize_at flip in stt-finalize, finalize_error stamp on terminal Chirp errors) |
| `clinical_memory`, `rag_memories` | yes (RAG retrieval — Phase 3) | yes (Phase 3) |
| `users.report_preferences` | yes (JSONB JOIN'd in `loadSessionContext` since 2026-05-18) | — |

## Auth model

- **stt-worker / llm-worker:** triggered by Eventarc. SA: `stt-worker@${PROJECT}.iam.gserviceaccount.com` and `llm-worker@${PROJECT}.iam.gserviceaccount.com`. Bindings managed in `infra/modules/cloud-functions/main.tf`:
  - `roles/speech.client` (stt only)
  - `roles/aiplatform.user` (llm only)
  - `roles/cloudsql.client`
  - `roles/cloudkms.cryptoKeyEncrypterDecrypter` on `app_data_key`
  - `roles/pubsub.publisher` (for `transcript.completed` / `report.generated`)
  - `roles/eventarc.eventReceiver`
  - `roles/storage.objectViewer` on audio bucket (stt only)
  - Pub/Sub service agent has `roles/iam.serviceAccountTokenCreator` on the worker SA (so Eventarc can act as the function's SA)
- **ai-pipeline-svc Cloud Run:** internal-only at IAM level (no `allUsers`).

## Pub/Sub topology

| Topic | Producer | Consumer | DLQ |
|---|---|---|---|
| `audio.objectFinalized` | GCS bucket notification on audio-uploads | ingestion-svc in-process subscriber goroutine | `audio.objectFinalized.dlq` |
| `audio.uploaded` | ingestion-svc subscriber (after probe + chunking) | stt-worker (Cloud Function) | `audio.uploaded.dlq` |
| `transcript.completed` | stt-worker | llm-worker | `transcript.completed.dlq` |
| `report.generated` | llm-worker | notification-svc | n/a yet |

Both worker triggers use `RETRY_POLICY_RETRY` (Eventarc retries on function error) — see commits `df41d59` / Phase 2 work. DLQ subscriptions (`stt-worker-dlq-reader`, `llm-worker-dlq-reader`) capture poison messages.

## Feature flags (feat/llm-optimisation)

Two env vars on the workers, both safe defaults:

| Flag | Default | Effect when default | Effect when flipped |
|---|---|---|---|
| `STT_NATIVE_DIARIZATION` (on stt-worker) | unset / `off` | Always-off regardless of language allow-list. Identical to pre-refactor behavior. | When `on`, allow-list (`chirp3DiarizationLanguages`) decides per-session. Languages flagged `false` still skip native diarization. |
| `LLM_DIARIZATION_MODE` (on llm-worker) | `json` | Call 1 uses schema-constrained JSON; current parsing path. | `markdown` → call 1 emits Markdown, parsed by `internal/diarization`. Call 2 is **always Format B Markdown** input regardless of this flag. |

**Ordering gate (docs/40, 2026-07-17):** dwie dodatkowe flagi na stt-worker:

| Flag | Default | Effect |
|---|---|---|
| `STT_ORDER_GATE` | `off` | `on` → ProcessAudio serializuje sesje per patient_file: gdy wcześniejsza sesja tej samej kartoteki jest w `CREATED..ANALYZING`, handler zwraca błąd = **CELOWY NACK** (Pub/Sub redelivery jest pętlą odpytującą, nie awarią). Filtr alertów błędów musi wykluczać komunikat `ordering gate: waiting for predecessor`. |
| `STT_ORDER_GATE_MAX_WAIT_H` | `12` | Okno bypass. TWARDY inwariant: < ~15 h budżetu retry subskrypcji (100 prób × ≤600 s, wire_dlq.sh) — inaczej czekające sesje spadają do DLQ. Test-strażnik: `TestOrderGateMaxWait_DLQSafetyInvariant`. |

Rollout pattern: ship both flags off, run the 3-session probe on a `--no-traffic` revision with `LLM_DIARIZATION_MODE=markdown`, gate the staging promotion on probe success. `STT_NATIVE_DIARIZATION=on` only after a per-language probe shows Chirp 3's tags are usable (today: all languages stay `false`).

Rollback = env-var flip. No DB / schema change.

## Constraints on iteration

**Safe:**
- Tweak chunker thresholds (re-run tests).
- Adjust the LLM prompt (via migration on `modalities.therapist_ai_general_prompt`).
- Add new fields to `ReportPayload` (extend JSON schema + struct + DB column).
- Add observability (slog fields).
- Add languages to `chirp3DiarizationLanguages` as `false`. Promotion to `true` needs probe evidence.

**Careful:**
- **JSON schema changes** — Gemini's structured output is strict. Adding required fields without updating the prompt → invalid responses. Adding optional fields with reasonable defaults is the safe path.
- **`session.language_code` writes** — ingestion-svc populates from `patient_user.ui_language` (BCP47-ized: `pl → pl-PL`, `en → en-US`, …). If you change the helper, also update its test; STT silently falls back to defaults otherwise.
- **Markdown parser grammar** — both `Group N — role` (cluster) and `Speaker N — role` (role-only) parse with the same state machine. Adding a new grammar variant requires updating the parser and its tests in lockstep.
Vertex Schema Type Mismatch: The Vertex AI Go SDK (genai.Schema) defines the Type field as an int32 enum (genai.TypeUnspecified = 0, genai.TypeString = 1, etc.). However, our report_schema.json correctly uses strings for types (e.g., "type": "object" or "type": "string").

Silent Failure: json.Unmarshal cannot cast a string like "object" into an int32 (genai.Type). This unmarshaling step silently fails (and the error is ignored via _ =), leaving the Type field as 0 (TypeUnspecified) for every single property in the schema.
API Rejection: When the payload is sent to Gemini, Vertex AI rejects the schema because all elements have a TypeUnspecified type. So use custom schema builder instead of json.Unmarshal.
- **Idempotency:** the `FOR UPDATE SKIP LOCKED` pattern is non-negotiable. If you reorder steps (e.g., delete audio before persisting transcript), you must re-think the recovery path.
- **`speaker_label_mapping` writes:** must include EVERY speaker in `transcript_segments`, otherwise UI shows blanks. The `generateAndSaveSpeakerLabels` function has the canonical logic — don't bypass it.

**Do NOT:**
- Add a `main()` to the worker `package sttworker`/`llmworker` (lint blocks; the framework provides one).
- Use the deprecated `cloud.google.com/go/pubsub` (v1). Always v2: `client.Publisher(name)`.
- Use `BatchRecognizeFileResult.Transcript` (deprecated). Use `fileResult.GetInlineResult().GetTranscript()`.
- Hardcode English "Therapist"/"Patient" labels in code or DB. Localized
  role labels are fine via `pkg/i18n/rolelabels.Generate` (ADR-IMPL-002 amended
  2026-05-25), but always go through that helper so the modality / language
  branching is in one place.
- Deploy workers via CI `gcloud functions deploy` — they're terraform-managed (`module.cloud_functions`).
- Set Vertex AI region to anything other than `europe-west4` (P3 violation).
- Hardcode session language. Always read from `session.language_code`. STT defaults to `pl-PL` only if the column is NULL — flag it as a bug if you see this in real sessions.
- Re-mount `/worker/stt` or `/worker/llm` on `cmd/server` (the Gin server). Those were dead stubs; production routes via Eventarc + Cloud Functions only.

## Local dev loop

```bash
cd services/ai-pipeline-svc

# Generate sqlc + proto
sqlc generate
buf generate ../../proto

# Test the chunker
cd ../../pkg/transcription && go test ./...

# Test stt-worker parsing
cd ../../services/ai-pipeline-svc && go test ./cmd/stt-worker/...

# Lint
golangci-lint run ./...
```

To exercise the full pipeline locally, you'd need:
1. Cloud Functions Framework: `funcframework` to invoke `ProcessAudio` / `ProcessTranscript` from a CloudEvent JSON.
2. Or deploy to staging via `terragrunt apply` (workers are terraform-managed; `module.cloud_functions` re-zips and uploads on every apply).

## Common gotchas

- **`init()` order matters.** Both worker `main.go`s have a defensive `init()` that gates `pgxpool.New`, Vertex client, KMS client on env vars. If a required env var is missing in CI tests, init crashes with `os.Exit(1)`. Use `cryptobox.NewMockBox()` fallback for tests.
- **`BatchRecognizeFileResult.GetInlineResult().GetTranscript()`** — the new way. Tests must construct fixtures using `BatchRecognizeFileResult_InlineResult{InlineResult: &speechpb.InlineResult{Transcript: ...}}`. See `cmd/stt-worker/main_test.go`.
- **JSON schema not generating:** `loadModalityPrompt` reads `modalities.therapist_ai_general_prompt` JSONB → expects shape `{"system": "...", "user": "..."}`. If migration 000008 didn't apply (Polish prompts), the column is empty and Gemini gets a blank prompt → garbage output.
- **Cold start on llm-worker:** Vertex AI client init can be ~1.5s. `min_instance_count = 0` per terraform. Acceptable for batch flow.
- **Chirp 3 native diarization is sparse, not complete.** Words often come back with `speaker_label=""` even when the request had `DiarizationConfig` set. If a session shows `sessions.speaker_label_mapping = {"1": ...}` (only one speaker) but the transcript clearly has multiple speakers, look at `transcript_segments` — `tag=0, label=""` rows are orphan chunks Chirp failed to label. `stt-worker.fillSpeakerLabels` + `llm-worker.markdownResultToPayload` orphan reattach handle the common case; if both fail, the next step is to disable native diarization for the language in `transcriptfmt.Chirp3DiarizationLanguages`.
- **MaxOutputTokens is a ceiling, not a target.** Setting `geminiMaxOutReportDefault` low (e.g. 4096) doesn't auto-shorten reports — the model only "knows" the cap by running into it (truncation mid-sentence). **You MUST pair every cap change with a `reportprefs.TargetLengthDirective`-style prompt directive** ("DOCELOWA DŁUGOŚĆ RAPORTU: …"). If you see truncations in Cloud Logging (`MaxOutputTokens` warns from the safety-retry path), the prompt directive isn't strong enough or the cap is too tight for that profile.
- **Preferences JSONB schema drift between identity-svc and reportprefs.** The two services duplicate the struct (`preferencesPayload` in identity-svc + `Preferences` in reportprefs) by design to avoid a cross-service Go import. Schema changes need to land in BOTH structs + the validator + the renderer label maps in the same PR. Doc-commented in both packages but easy to forget — `go test` won't catch a drift until a runtime decode fails.

## Source-doc pointers

- `docs/06_FAZA_2_INGESTION_AI.md` lines 1759–end — Sprints 2.5 (STT worker), 2.6 (LLM worker), 2.7+ (memory).
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §4.2.5 (lines 441–465), §8 (Pipeline AI, lines 835–1023).
- `docs/03_DATA_MODEL.md` §4.6, §4.7 (RAG), §4.8 (HiTOP).
- ADR-IMPL-001 to 007 (`docs/06_*.md` lines 102–379) — read all of them.
