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
# IAM: llm-worker może publishować report.generated
resource "google_pubsub_topic_iam_member" "llm_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.report_generated.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:llm-worker@${var.project_id}.iam.gserviceaccount.com"
}

output "audio_uploaded_topic" { value = google_pubsub_topic.audio_uploaded.id }
output "transcript_completed_topic" { value = google_pubsub_topic.transcript_completed.id }
output "report_generated_topic" { value = google_pubsub_topic.report_generated.id }
