variable "project_id" {
  type = string
}

variable "location" {
  type    = string
  default = "europe-central2"
}

resource "google_storage_bucket" "audio_uploads" {
  name          = "${var.project_id}-audio-uploads"
  project       = var.project_id
  location      = var.location
  force_destroy = true

  uniform_bucket_level_access = true

  # 48h (2 days) Object Lifecycle Management rule as per Phase 2 requirements
  lifecycle_rule {
    condition {
      age = 2
    }
    action {
      type = "Delete"
    }
  }
}

variable "pubsub_topic_id" {
  type = string
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

resource "google_pubsub_topic_iam_binding" "binding" {
  topic   = var.pubsub_topic_id
  role    = "roles/pubsub.publisher"
  members = ["serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"]
}

resource "google_storage_notification" "notification" {
  bucket         = google_storage_bucket.audio_uploads.name
  payload_format = "JSON_API_V1"
  topic          = var.pubsub_topic_id
  event_types    = ["OBJECT_FINALIZE"]
  depends_on     = [google_pubsub_topic_iam_binding.binding]
}

output "audio_uploads_bucket_name" {
  value = google_storage_bucket.audio_uploads.name
}

