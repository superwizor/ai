---
description: Loads when editing ai-pipeline-svc (stt-worker, llm-worker, chunker, RAG, HiTOP).
globs:
  - "superwizor-backend/services/ai-pipeline-svc/**"
  - "superwizor-backend/pkg/transcription/**"
  - "superwizor-backend/pkg/i18n/speakerlabels/**"
  - "superwizor-backend/pkg/cryptobox/**"
  - "superwizor-backend/proto/ai_pipeline/**"
  - "superwizor-backend/gen/go/ai_pipeline/**"
  - "superwizor-backend/infra/modules/cloud-functions/**"
alwaysApply: false
---

# ai-pipeline-svc (stt-worker, llm-worker, chunker)

**Read [`docs/agents/05_ai-pipeline-svc.md`](../../docs/agents/05_ai-pipeline-svc.md) before editing.** This is the densest area in the codebase — most ADRs constrain it.

Quick orientation:

- **Three workloads under one Go module:**
  1. `cmd/stt-worker/` — Cloud Functions Gen2; entry `ProcessAudio`; `package sttworker`.
  2. `cmd/llm-worker/` — Cloud Functions Gen2; entry `ProcessTranscript`; `package llmworker`.
  3. `cmd/server/` — Cloud Run gRPC server (auxiliary).

- **Workers are NOT `package main`** — never add `func main()`. The Cloud Functions framework registers entry points via `init()` calling `functions.CloudEvent(...)`. golangci-lint's `unused` linter blocks rogue `main()`s.

- **ADR-IMPL-001:** Chirp 3 (not 2); STT endpoint `eu-speech.googleapis.com:443` (P3 EU residency).
- **ADR-IMPL-003:** Gemini 2.5 PRO via Vertex AI in `europe-west4`. Structured output via `response_mime_type=application/json` + `response_schema` from `cmd/llm-worker/schemas/report_schema.json`.
- **ADR-IMPL-004:** Workers are Cloud Functions Gen2, NOT Cloud Run services. Deployed by terraform (`module.cloud_functions`), NOT by CI.
- **ADR-IMPL-006:** `transcripts.transcript_ciphertext` is the **canonical blob**. Segments are derived. The `BlobLine` JSON struct in `cmd/stt-worker/main.go` is the wire format.
- **ADR-IMPL-007:** Polish (`pl-PL`) has no native Chirp 3 diarization. STT produces flat words; `pkg/transcription/chunker.ChunkByPauses` segments by pauses ≥600ms; LLM does speaker clustering + role inference in one call.

- **Idempotency at worker entry:** `SELECT status FROM sessions WHERE id=$1 FOR UPDATE SKIP LOCKED`. If status already advanced, ACK Pub/Sub without doing work.

- **Speaker labels:** `pkg/i18n/speakerlabels.Generate(langCode, tag)` produces `"Osoba 1"`, `"Osoba 2"`. NEVER hardcode "Therapist"/"Patient" anywhere (ADR-IMPL-002).

- **Modality prompts** live in `modalities.therapist_ai_general_prompt` JSONB. Change via migration (e.g., `000008_modality_prompts_pl.up.sql`); never UPDATE in place outside migrations.

- **Common code gotchas:**
  - `BatchRecognizeFileResult.Transcript` is deprecated → `fileResult.GetInlineResult().GetTranscript()`.
  - `cloud.google.com/go/pubsub` is deprecated → `pubsub/v2`; `client.Publisher(name)`.
  - Test fixtures use `BatchRecognizeFileResult_InlineResult{InlineResult: &speechpb.InlineResult{Transcript: ...}}`.

- **Deploy path:** `cd infra/environments/staging && terragrunt apply -target=module.cloud_functions`. Source is re-zipped on every apply via `package.sh`.
