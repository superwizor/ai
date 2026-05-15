# ai-pipeline-svc

> Read [`00_GLOBAL_CONTEXT.md`](./00_GLOBAL_CONTEXT.md) first.

## Mission

The most critical service. Three workloads under one Go module:
1. **`stt-worker`** (Cloud Functions Gen2) — Pub/Sub-triggered. Calls Chirp 3 STT in the session's audio language, optionally enables native diarization per a static language allow-list, persists transcript, publishes `transcript.completed`, deletes audio (P1 + ADR-IMPL-006).
2. **`llm-worker`** (Cloud Functions Gen2) — Pub/Sub-triggered. Loads transcript, runs LLM diarization + clinical analysis (Gemini 2.5 Flash-Lite today), persists report + HiTOP measurements, publishes `report.generated`. Branches at call-1 between "cluster + label" (no native speakers) and "label only" (native speakers from Chirp).
3. **`ai-pipeline-svc` Cloud Run service** — `/health` only since `feat/llm-optimisation`. Historical Gin worker stubs (`STTWorkerHandler` / `LLMWorkerHandler`) were dead code; removed.

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
    └── models/, services/

pkg/transcription/chunker/           # ChunkByPauses, used by stt-worker
pkg/i18n/speakerlabels/              # Generate(langCode, tag) → "Osoba 1" etc.
pkg/cryptobox/                       # envelope encryption
```

**Critical:** `cmd/stt-worker/main.go` is `package sttworker`, `cmd/llm-worker/main.go` is `package llmworker`. **Do NOT add `func main()`** — they're Cloud Functions Gen2; the framework provides the entry point. `golangci-lint`'s `unused` linter flags any `main()` here.

## Pipeline flow

```
ingestion-svc CompleteAudioUpload:
  - copies patient_user.ui_language → session.language_code (BCP47-ized)
  - creates audio_upload + signed URL
       ↓
Flutter PUT to GCS
       ↓
GCS OBJECT_FINALIZE → Eventarc → Pub/Sub audio.uploaded
       ↓
stt-worker (ProcessAudio):
  1. update sessions.status = TRANSCRIBING
  2. lang := session.language_code (was hardcoded "pl-PL"; now from patient)
  3. nativeDiarize := chirp3DiarizationLanguages[lang]    (static map, defaults all-false)
  4. transcribeAudio(gcsURI, lang, useNativeDiarization=nativeDiarize)
       → Chirp 3 BatchRecognize, eu-speech.googleapis.com endpoint
       → returns []chunker.Word (with timestamps + confidence;
         speaker_tag populated when native diarization is on)
  5. chunker.ChunkByPauses(words, DefaultConfig{600ms, 300ms, 60s})
       → []chunker.Chunk (speaker_tag flows through chunk grouping)
  6. persistTranscript: encrypt blob → transcripts row + transcript_segments
       (per ADR-IMPL-006, blob is canonical; segments.speaker_tag = native or 0)
  7. update sessions.status = ANALYZING
  8. publishTranscriptCompleted on transcript.completed
  9. (TODO: delete audio object — currently relies on GCS OLM 48h)
 10. ACK Pub/Sub
       ↓
Pub/Sub transcript.completed
       ↓
llm-worker (ProcessTranscript):
  1. load SessionContext (sessions row + speaker_label_mapping)
  2. loadTranscriptBlob: decrypt → []BlobLine
  3. hasNativeSpeakers := any(BlobLine.speaker_tag != 0)
  4. loadRAGContext (Phase 2: stub returns "")
  5. loadModalityPrompt (from modalities.therapist_ai_general_prompt JSONB)
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
  7. generateAndSaveSpeakerLabels:
       walk SpeakerGroups → assign sequential speaker_tags (skip filler/unknown)
       speakerlabels.Generate(langCode, tag)
       update transcript_segments + sessions.speaker_label_mapping
  8. Call 2 (clinical report):
       transcript text: always Format B (speaker-turn Markdown, labels now resolved)
       Markdown text output (unchanged)
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

## Constraining ADRs (this service is the densest)

| ADR | What it forces |
|---|---|
| **ADR-IMPL-001** | Chirp 3 (NOT Chirp 2); `eu-speech.googleapis.com` endpoint for EU residency |
| **ADR-IMPL-002** | Speaker labels are neutral + localized; generated by `pkg/i18n/speakerlabels`; never "Therapist"/"Patient" in storage |
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

## Native-diarization sparse-label recovery (2026-05-15)

Chirp 3's native diarization is **not** "every word gets a speaker_label". In practice it labels the dominant speaker reliably and drops labels on the other speaker's words (and on short interjections / filler). On session `26ecf316` we observed: 295 words, 8 chunks correctly `tag=1` (~195 words, therapist), 12 chunks interleaved at the patient's timestamps stuck at `tag=0, label=""` (~100 words). The LLM call-1 still inferred two speakers from content, but `markdownResultToPayload` found zero chunks with `SpeakerTag=2` → patient `SpeakerGroup.ChunkIndices=null` → `generateAndSaveSpeakerLabels` never wrote `tag=2` rows → UI rendered "Person 1" only.

Two-layer mitigation. Both stay enabled whenever `useNativeDiarization=true`:

**Layer 1 (signal-level, stt-worker)** — `fillSpeakerLabels(words, maxGapMS)` runs between `transcribeAudio` and `chunker.ChunkByPauses`. Forward pass: propagates the most recently-seen non-empty `SpeakerLabel` into adjacent unlabeled words. Backward pass: same for leading unlabeled words (Chirp's first label appears later in the stream). **Both bounded by `chunker.DefaultConfig().PauseThresholdMS` (600ms)** — pauses are our only signal that the speaker may have changed, so we never propagate across them. Mutates the word slice in place.

**Layer 2 (defensive, llm-worker)** — in `markdownResultToPayload(native=true)`, after collecting chunks per LLM-inferred speaker: if **exactly one** `SpeakerGroup` ended up with zero `ChunkIndices` AND there are `SpeakerTag=0` orphan chunks, give all orphans to the empty group. The LLM saw the transcript content and concluded N speakers exist; a single empty group is the "Chirp only labeled the other speaker" case. **Multiple** empty groups → log a warning, skip — we don't have enough signal to guess which orphan goes where.

Trade-offs:
- Layer 1 can mis-attribute if Chirp labels only one speaker AND the unlabeled run is genuinely the other speaker without a pause between them. We accept this — the pause boundary is the strongest signal we have. If Chirp's labeling reliability ever degrades further, the fallback is to disable native diarization for that language in `transcriptfmt.Chirp3DiarizationLanguages`.
- Layer 2 assumes the LLM doesn't hallucinate a missing speaker. The role-only prompt forces the LLM to label only the speakers visible in Format B input; if it adds a speaker that isn't in the transcript, that's a different bug (we'd see hallucinated text in the report too).

Tests: `TestFillSpeakerLabels` in `services/ai-pipeline-svc/cmd/stt-worker/main_test.go` covers forward fill, pause-boundary stop, backward fill, all-unlabeled no-op, all-labeled invariant, empty input, and the session-26ecf316 shape. Run with `go test ./services/ai-pipeline-svc/cmd/stt-worker/...`.

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
| `clinical_memory`, `rag_memories` | yes (RAG retrieval — Phase 3) | yes (Phase 3) |

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
| `audio.uploaded` | ingestion-svc + GCS Eventarc | stt-worker (Cloud Function) | `audio.uploaded.dlq` |
| `transcript.completed` | stt-worker | llm-worker | `transcript.completed.dlq` |
| `report.generated` | llm-worker | notification-svc (Phase 3) | n/a yet |

Both worker triggers use `RETRY_POLICY_RETRY` (Eventarc retries on function error) — see commits `df41d59` / Phase 2 work. DLQ subscriptions (`stt-worker-dlq-reader`, `llm-worker-dlq-reader`) capture poison messages.

## Feature flags (feat/llm-optimisation)

Two env vars on the workers, both safe defaults:

| Flag | Default | Effect when default | Effect when flipped |
|---|---|---|---|
| `STT_NATIVE_DIARIZATION` (on stt-worker) | unset / `off` | Always-off regardless of language allow-list. Identical to pre-refactor behavior. | When `on`, allow-list (`chirp3DiarizationLanguages`) decides per-session. Languages flagged `false` still skip native diarization. |
| `LLM_DIARIZATION_MODE` (on llm-worker) | `json` | Call 1 uses schema-constrained JSON; current parsing path. | `markdown` → call 1 emits Markdown, parsed by `internal/diarization`. Call 2 is **always Format B Markdown** input regardless of this flag. |

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
- Hardcode "Therapist"/"Patient" labels in code or DB (violates ADR-IMPL-002).
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

## Source-doc pointers

- `docs/06_FAZA_2_INGESTION_AI.md` lines 1759–end — Sprints 2.5 (STT worker), 2.6 (LLM worker), 2.7+ (memory).
- `docs/02_ARCHITEKTURA_TECHNICZNA.md` §4.2.5 (lines 441–465), §8 (Pipeline AI, lines 835–1023).
- `docs/03_DATA_MODEL.md` §4.6, §4.7 (RAG), §4.8 (HiTOP).
- ADR-IMPL-001 to 007 (`docs/06_*.md` lines 102–379) — read all of them.
