variable "project_id" { type = string }
variable "region" { type = string }
variable "network_id" { type = string }
variable "vpc_connector_id" { type = string }
variable "db_connection_name" { type = string }
variable "db_url_secret_id" { type = string }
variable "audio_bucket_name" { type = string }
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
