---
description: Loads when editing clinical-svc (patient files, sessions, reports, speaker labels, feedback).
globs:
  - "superwizor-backend/services/clinical-svc/**"
  - "superwizor-backend/proto/clinical/**"
  - "superwizor-backend/gen/go/clinical/**"
  - "superwizor-backend/migrations/*clinical*.sql"
  - "superwizor-backend/migrations/*sessions*.sql"
  - "superwizor-backend/migrations/*feedback*.sql"
alwaysApply: false
---

# clinical-svc

**Read [`docs/agents/02_clinical-svc.md`](../../docs/agents/02_clinical-svc.md) before editing.**

Quick orientation:

- **The core of the product.** Most Flutter actions hit this. Owns patient files, sessions, modalities, **read-only** therapist reports.
- **Tables owned:** Clinical (`modalities`, `patient_files`, `therapist_patient_relations`), Sessions (`sessions`, `transcripts`, `transcript_segments`, `therapist_reports`, `patient_views`, `audio_uploads`, `upload_tickets`), Feedback (`report_feedback`, `feedback_categories`, ...).
- **P4 — never add a write-report endpoint.** Reports are written exclusively by `ai-pipeline-svc`'s `llm-worker`.
- **ADR-IMPL-006 — `transcripts.transcript_ciphertext` is canonical.** Speaker label edits MUST rebuild that blob in the same transaction. See `internal/adapters/grpc/labels.go::UpdateSpeakerLabels`.
- **ADR-DM-008 — `therapist_reports` and `patient_views` are physically separate tables.** Don't JOIN across the boundary in app logic.
- **PHI columns are envelope-encrypted** (ADR-DM-002). Use `pkg/cryptobox.Decrypt` when reading.
- Calls `billing-svc.CheckQuota` before allowing new sessions/uploads (Phase 2 stub returns true).
