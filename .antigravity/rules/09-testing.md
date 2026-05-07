---
description: Loads when working on tests (unit, integration, E2E shell + Go).
globs:
  - "tests/**"
  - "**/*_test.go"
  - "**/testdata/**"
  - "**/*.test.dart"
  - "superwizor-backend/services/migrator/**"
  - "test-audio.*"
alwaysApply: false
---

# Testing

**Read [`docs/agents/09_testing.md`](../../docs/agents/09_testing.md) before editing.**

Quick orientation:

- **Pyramid:**
  - Unit (`*_test.go` colocated) — fast, run every push via `make test`.
  - Integration — limited today; expand as needed.
  - E2E shell (`tests/e2e/*.sh`) — Phase 1 smoke covered.
  - **E2E full pipeline (audio → transcript → report) — gap.** See `docs/agents/09_testing.md` for the priority-ordered scenario list.

- **Test against staging.** No separate test project. Use clearly-fake data (`firebase_uid: "test_uid_<timestamp>"`, `email: "test_*@example.com"`, `working_alias: "E2E Test ..."`).

- **Two auth paths:**
  - `gcloud auth print-identity-token` → Google IAM token. Works for `allUsers`-bound services, but doesn't exercise Firebase token validation.
  - Real Firebase ID token (mint via Firebase Admin SDK + `signInWithCustomToken`) — required for testing Firebase claim validation.

- **Idempotency MUST be tested** (P1). Re-deliver Pub/Sub messages, retry mutating gRPC calls with same `idempotency_key`, assert single-effect.

- **Speaker label rebuild is critical to test** (ADR-IMPL-006). After `UpdateSpeakerLabels`, the canonical `transcripts.transcript_ciphertext` blob MUST change — decrypt and verify new labels appear in blob lines.

- **No English audio.** Polish-only (`pl-PL`) per ADR-IMPL-007. The LLM diarization path is tuned for Polish; English fixtures lie.

- **Build tag `// +build e2e`** on Go E2E tests so they don't run in `make test`. Dedicated CI job with `go test -tags=e2e`.

- **Common gotchas:**
  - Vertex AI cold start ~15s on first invocation; budget wait time.
  - `speaker_label_mapping` JSON keys are STRINGS (`"1"` not `1`).
  - Don't ACK Pub/Sub messages while testing — `--auto-ack=false`.
  - Staging DB accumulates test data — add nightly cleanup job for soft-deleted test users.

- **Tooling:** `grpcurl` (TLS to Cloud Run :443), `gcloud` (auth + service discovery), `cloud-sql-proxy` + `psql` (DB assertions), `gsutil`/`gcloud storage` (GCS), Go `testing` + `testify` for in-process tests, `pkg/cryptobox.NewMockBox()` for round-trip tests.
