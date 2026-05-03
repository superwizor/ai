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
