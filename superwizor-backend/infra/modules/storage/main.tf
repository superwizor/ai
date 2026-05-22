variable "project_id" {
  type = string
}

variable "project_number" {
  type        = string
  description = "GCP project number. Used to construct the Speech-to-Text Service Agent principal that needs write access to the transcripts-raw bucket (Chirp writes BatchRecognize output there on the caller's behalf)."
}

variable "location" {
  type    = string
  default = "europe-central2"
}

variable "app_data_key_id" {
  type        = string
  description = "KMS key for CMEK on the transcripts-raw bucket. Same key as the transcripts.transcript_ciphertext column + audio_uploads encryption (ADR-DM-002). Chirp output is briefly-resident PHI."
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

  cors {
    origin          = ["*"]
    method          = ["PUT", "OPTIONS"]
    response_header = ["Content-Type", "x-goog-content-length-range"]
    max_age_seconds = 3600
  }
}

variable "pubsub_topic_id" {
  type = string
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

resource "google_pubsub_topic_iam_member" "binding" {
  topic   = var.pubsub_topic_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

resource "google_storage_notification" "notification" {
  bucket         = google_storage_bucket.audio_uploads.name
  payload_format = "JSON_API_V1"
  topic          = var.pubsub_topic_id
  event_types    = ["OBJECT_FINALIZE"]
  depends_on     = [google_pubsub_topic_iam_member.binding]
}

output "audio_uploads_bucket_name" {
  value = google_storage_bucket.audio_uploads.name
}

# ============================================================================
# transcripts-raw bucket (Stage 1 of feat/stt-long_audio_support)
#
# Holds Chirp BatchRecognize output JSON files briefly. stt-submit
# (refactored stt-worker) writes GcsOutputConfig.Uri pointing here;
# stt-finalize reads via OBJECT_FINALIZE Eventarc trigger.
#
# CMEK encrypted with the same app-data key as transcripts column +
# audio bucket (ADR-DM-002). OLM 7d — generous enough for a weekend
# of debugging; well under the 30d residence ceiling.
# ============================================================================

resource "google_storage_bucket" "transcripts_raw" {
  name          = "${var.project_id}-transcripts-raw"
  project       = var.project_id
  location      = var.location
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  encryption {
    default_kms_key_name = var.app_data_key_id
  }

  versioning {
    enabled = false
  }

  lifecycle_rule {
    condition {
      age = 7
    }
    action {
      type = "Delete"
    }
  }
}

# IAM grant: Speech-to-Text Service Agent needs to write to the bucket
# on the caller's behalf when GcsOutputConfig is set on
# BatchRecognize. The agent principal follows the convention
# `service-{project-number}@gcp-sa-v2-speech.iam.gserviceaccount.com`
# — auto-provisioned the first time the project enables speech.googleapis.com.
resource "google_storage_bucket_iam_member" "transcripts_raw_speech_agent" {
  bucket = google_storage_bucket.transcripts_raw.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:service-${var.project_number}@gcp-sa-v2-speech.iam.gserviceaccount.com"
}

# Speech agent also needs KMS encrypt/decrypt to write CMEK objects.
# Without this, BatchRecognize fails with PERMISSION_DENIED on the
# Cloud KMS key.
resource "google_kms_crypto_key_iam_member" "transcripts_raw_speech_agent_kms" {
  crypto_key_id = var.app_data_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${var.project_number}@gcp-sa-v2-speech.iam.gserviceaccount.com"
}

output "transcripts_raw_bucket_name" {
  value = google_storage_bucket.transcripts_raw.name
}

