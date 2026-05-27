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
# One source bundle (cmd/worker) is wrapped by THREE Cloud Functions, each
# bound to its own Eventarc Pub/Sub trigger:
#   - on-uploaded   → audio.uploaded       → ProcessAudioUploaded
#   - on-transcribed→ transcript.completed → ProcessTranscriptCompleted
#   - on-report     → report.generated     → ProcessReportGenerated
# ----------------------------------------------------------------------------

variable "notification_worker_source_dir" {
  type        = string
  description = "Path to services/notification-svc (cmd/worker is one of its packages)"
}

variable "notification_worker_sa_email" {
  type        = string
  description = "Email of the notification-svc service account (shared by Cloud Run server + 3 worker functions)"
}

variable "report_generated_topic" {
  type        = string
  description = "Pub/Sub topic ID for report.generated (final fan-out → FCM push + Firestore done)"
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
