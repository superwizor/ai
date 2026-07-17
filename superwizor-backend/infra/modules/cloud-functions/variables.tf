variable "project_id" { type = string }
variable "region" { type = string }
variable "network_id" { type = string }
variable "vpc_connector_id" { type = string }
variable "db_connection_name" { type = string }
variable "db_url_secret_id" { type = string }
variable "audio_bucket_name" { type = string }
variable "transcripts_raw_bucket_name" {
  type        = string
  description = "GCS bucket where Chirp BatchRecognize writes its output (Stage 1 of feat/stt-long_audio_support). stt-submit sets GcsOutputConfig.Uri here; stt-finalize OBJECT_FINALIZE triggers off it."
}
variable "audio_uploaded_topic" { type = string }
variable "transcript_completed_topic" { type = string }
variable "session_status_changed_topic" { type = string }
variable "stt_worker_source_dir" { type = string }
variable "llm_worker_source_dir" { type = string }
variable "stt_worker_sa_email" {
  type        = string
  description = "The email of the STT worker service account"
}

variable "llm_worker_sa_email" {
  type        = string
  description = "The email of the LLM worker service account"
}

variable "dev_log_plaintext_transcript" {
  type        = bool
  default     = false
  description = <<-EOT
    When true, stt-worker logs the full plaintext transcript to Cloud
    Logging immediately after Chirp 3 returns. Useful for staging
    debugging when STT silently produces empty/wrong output, but exposes
    PHI in logs — must be left `false` on any environment that processes
    real patient sessions. The corresponding env var
    DEV_LOG_PLAINTEXT_TRANSCRIPT is read by services/ai-pipeline-svc/
    cmd/stt-worker/main.go::logPlaintextTranscript.
  EOT
}

variable "audio_uploaded_dlq_topic" {
  type        = string
  description = "Pub/Sub topic ID for audio.uploaded dead-letter messages"
}

variable "transcript_completed_dlq_topic" {
  type        = string
  description = "Pub/Sub topic ID for transcript.completed dead-letter messages"
}

# ----------------------------------------------------------------------------
# notification-svc worker inputs (Phase 3 — Sprints 3.3 + 3.5)
#
# One source bundle (cmd/worker) is wrapped by Cloud Functions, each bound
# to its own Eventarc Pub/Sub trigger. docs/21 Faza-4 retired the two pure
# status mirrors (on-uploaded, on-transcribed) into on-status:
#   - on-status   → session.status_changed → ProcessSessionStatusChanged
#                   (whole lifecycle mirror — uploaded/transcribing/analyzing/
#                    done/failed/cancelled — AND, on "done", the report-ready
#                    FCM push + inbox doc via handleReportReady)
#   - on-deleted  → session.deleted         → ProcessSessionDeleted (RODO erase)
#
# Retired (docs/21 Faza-4): on-uploaded, on-transcribed (pure mirrors) and
# on-report (its FCM push folded into on-status's "done" branch).
# ----------------------------------------------------------------------------

variable "notification_worker_source_dir" {
  type        = string
  description = "Path to services/notification-svc (cmd/worker is one of its packages)"
}

variable "notification_worker_sa_email" {
  type        = string
  description = "Email of the notification-svc service account (shared by Cloud Run server + 3 worker functions)"
}

variable "session_deleted_topic" {
  type        = string
  description = "Pub/Sub topic ID for session.deleted (clinical-svc → notification-worker-on-deleted cleanup of Firestore mirror + inbox)"
}

variable "billing_svc_url" {
  type        = string
  description = "Cloud Run URL for billing-svc — passed to stt-worker as BILLING_SVC_URL env so post-STT finalize can call CommitUsage. Empty disables the billing hook."
  default     = ""
}

# ── Deepgram provider (docs/39_DEEPGRAM_STT_MIGRATION.md) ─────────────

variable "deepgram_api_url" {
  type = string
  # EU-resident endpoint ONLY. The worker refuses to start on any other
  # value; this variable exists for test doubles, not for region choice.
  default = "https://api.eu.deepgram.com"
}

variable "deepgram_api_key_secret_id" {
  type = string
  # Secret Manager secret name holding the Deepgram API key. Empty
  # disables the provider entirely (no secret mount, worker falls back
  # to chirp regardless of STT_PROVIDER).
  default = "deepgram-api-key"
}

variable "stt_provider" {
  type = string
  # "chirp" | "deepgram". Default chirp until the docs/39 Faza-3 canary
  # completes. Kill-switch: flip back + terragrunt apply.
  default = "chirp"
}

variable "stt_provider_allowlist" {
  type = string
  # CSV of therapist/org UUIDs canaried onto deepgram while the default
  # stays chirp. Empty = no canary.
  default = ""
}
