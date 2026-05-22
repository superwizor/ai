variable "project_id" {
  type = string
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

# Cloud Storage service account — needs Encrypter/Decrypter on
# app_data_key so the CMEK-encrypted transcripts_raw bucket can be
# created. modules/kms already grants this for audio_bucket_key on
# the audio uploads bucket, but app_data_key has a separate IAM
# policy. Without this binding, bucket creation 403s on the KMS key.
data "google_storage_project_service_account" "gcs_account_for_transcripts" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "transcripts_raw_gcs_kms" {
  crypto_key_id = var.app_data_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account_for_transcripts.email_address}"
}

# Speech-to-Text Service Agent identity. Auto-provisioned by GCP when
# the project first uses speech.googleapis.com — but the IAM binding
# below references it BEFORE it has reason to exist on a fresh
# project. Forcing creation via google_project_service_identity makes
# the binding work on the first apply.
resource "google_project_service_identity" "speech_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "speech.googleapis.com"
}

# GCS service account → Pub/Sub publisher (project-wide). Eventarc
# OBJECT_FINALIZE triggers create an internal Pub/Sub topic that the
# GCS service account publishes to whenever objects land in the
# transcripts_raw bucket. Without this, Eventarc trigger creation
# fails with "Cloud Storage service account ... is unable to publish".
# See: https://cloud.google.com/eventarc/docs/run/quickstart-storage#before-you-begin
resource "google_project_iam_member" "gcs_eventarc_publisher" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${data.google_storage_project_service_account.gcs_account_for_transcripts.email_address}"
}

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

  # Order matters: KMS IAM must land before the bucket because
  # the bucket creation requires the Cloud Storage SA to be able
  # to use the key.
  depends_on = [google_kms_crypto_key_iam_member.transcripts_raw_gcs_kms]
}

# Speech-to-Text Service Agent needs to write to the bucket on the
# caller's behalf when GcsOutputConfig is set on BatchRecognize.
resource "google_storage_bucket_iam_member" "transcripts_raw_speech_agent" {
  bucket = google_storage_bucket.transcripts_raw.name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_project_service_identity.speech_agent.email}"
}

# Speech agent also needs KMS encrypt/decrypt to write CMEK objects.
# Without this, BatchRecognize fails with PERMISSION_DENIED on the
# Cloud KMS key.
resource "google_kms_crypto_key_iam_member" "transcripts_raw_speech_agent_kms" {
  crypto_key_id = var.app_data_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.speech_agent.email}"
}

output "transcripts_raw_bucket_name" {
  value = google_storage_bucket.transcripts_raw.name
}

