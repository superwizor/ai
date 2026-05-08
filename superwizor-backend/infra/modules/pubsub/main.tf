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

# DLQ for best-effort Firestore writes from notification-svc worker
# (ADR-IMPL-009). Failed writes get published here so:
#   - alerting policy can fire on undelivered_messages > 0
#   - operators can replay via the pull subscription below
# This NEVER blocks the clinical pipeline — the worker ACKs Pub/Sub even
# when the Firestore write fails (and forwards the message here for
# observability instead).
resource "google_pubsub_topic" "firestore_sync_dlq" {
  name    = "firestore-sync.dlq"
  project = var.project_id
}

resource "google_pubsub_subscription" "firestore_sync_dlq_reader" {
  name    = "firestore-sync-dlq-reader"
  project = var.project_id
  topic   = google_pubsub_topic.firestore_sync_dlq.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days

  expiration_policy {
    ttl = ""
  }
}

# notification-svc may publish to firestore-sync.dlq when a Firestore
# write fails (Phase 4 wiring; for now the worker logs only — the
# binding is here so it's ready when the publish-on-failure code lands).
resource "google_pubsub_topic_iam_member" "notification_firestore_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.firestore_sync_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:notification-svc@${var.project_id}.iam.gserviceaccount.com"
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
output "audio_uploaded_dlq_topic" { value = google_pubsub_topic.audio_uploaded_dlq.id }
output "transcript_completed_dlq_topic" { value = google_pubsub_topic.transcript_completed_dlq.id }
output "firestore_sync_dlq_topic" { value = google_pubsub_topic.firestore_sync_dlq.id }
output "firestore_sync_dlq_subscription" { value = google_pubsub_subscription.firestore_sync_dlq_reader.id }
output "firestore_sync_dlq_subscription_name" { value = google_pubsub_subscription.firestore_sync_dlq_reader.name }
