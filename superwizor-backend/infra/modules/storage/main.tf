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

# Option F (feat/refactor-stt-architecture, 2026-05-25). When set, a
# google_storage_notification on the audio-uploads bucket fans OBJECT_FINALIZE
# events into this Pub/Sub topic. ingestion-svc's in-process pull subscriber
# consumes them and drives the async ingestion finalization pipeline.
# Empty string disables the wiring (legacy synchronous path).
variable "audio_object_finalized_topic_name" {
  type        = string
  description = "Pub/Sub topic name (NOT id) for OBJECT_FINALIZE events fanned out from the audio-uploads bucket. See modules/pubsub/main.tf."
  default     = ""
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

  # Browser uploads via V4 signed URLs trigger a CORS pre-flight that
  # GCS itself answers. The origin list mirrors the same allowlist the
  # in-app Go CORS middleware enforces on the gRPC side — superwizor.ai
  # marketing site, app.superwizor.ai therapist/admin console, plus
  # localhost dev ports. We tightened from "*" to exact-match in
  # Slice 1 of feat/web-app (docs/18 R2 + R6 P2 Zero-Trust). The
  # signed URL itself carries auth (no browser credentials sent), but
  # the explicit allowlist still cuts the blast radius if a leaked
  # URL ever ends up on a third-party page.
  #
  # response_header serves DOUBLE DUTY in GCS CORS: it's both the
  # Access-Control-Allow-Headers list (for what the request may send)
  # AND the Access-Control-Expose-Headers list (for what the response
  # exposes). x-goog-meta-* must be here because ingestion-svc's
  # CreateAudioUpload includes that header in the upload contract.
  cors {
    origin = [
      "https://superwizor.ai",
      "https://app.superwizor.ai",
      "http://localhost:3000",
      "http://localhost:8080",
    ]
    method = ["PUT", "OPTIONS"]
    response_header = [
      "Content-Type",
      "x-goog-content-length-range",
      "x-goog-meta-source",
      "x-goog-meta-*",
    ]
    max_age_seconds = 3600
  }
}

# NOTE: the audio_uploads bucket used to have a google_storage_notification
# fan-out to the `audio.uploaded` Pub/Sub topic. That was the legacy way to
# kick off STT — but ingestion-svc.PublishAudioUploaded is now the sole
# legitimate publisher, emitting structured {session_id, upload_id, ...}
# JSON. The bucket notification was a duplicate publisher emitting raw
# storage#object events that no downstream subscriber could parse:
# stt-worker logged "missing session_id or object_path, ignoring event"
# and ack'd, but notification-worker-on-uploaded *returned* an error,
# so Pub/Sub kept redelivering with backoff. Under load that backlog
# delayed the legitimate event by minutes and, combined with the lack
# of monotonic ordering in firestore/writer.go::WriteSessionState,
# caused sessions to silently regress status="done" → "uploaded" in
# Firestore — leaving Flutter stuck on the transcription stepper.
# Removed 2026-05-23. See worker fan-out in cmd/worker/main.go and
# monotonic guard in firestore/writer.go.

output "audio_uploads_bucket_name" {
  value = google_storage_bucket.audio_uploads.name
}

# Option F: re-introduce a bucket notification on audio-uploads, this time
# routed to the dedicated audio.objectFinalized topic (NOT the structured
# audio.uploaded topic). The 2026-05-23 incident that motivated removing
# the original notification was caused by routing raw bucket events at
# `audio.uploaded`, where downstream workers expected structured payloads
# and couldn't parse them. With a dedicated topic, ingestion-svc's
# in-process subscriber is the sole consumer and republishes a structured
# audio.uploaded after probing + chunking.
#
# Gated by audio_object_finalized_topic_name to keep the legacy synchronous
# path intact when the variable is empty. The Pub/Sub service agent must
# already be a pubsub.publisher on the target topic (granted via
# gcs_eventarc_publisher above, which is project-wide).
resource "google_storage_notification" "audio_uploads_object_finalized" {
  count          = var.audio_object_finalized_topic_name == "" ? 0 : 1
  bucket         = google_storage_bucket.audio_uploads.name
  payload_format = "JSON_API_V1"
  # google_storage_notification accepts EITHER a bare topic name or a
  # fully-qualified projects/<id>/topics/<name>. The bare name form
  # currently trips a "project: required field is not set" terraform
  # error in google-provider 6.50 (it tries to default but the bucket
  # resource is in a different module scope). The fully-qualified
  # form bypasses that path entirely.
  topic       = "projects/${var.project_id}/topics/${var.audio_object_finalized_topic_name}"
  event_types = ["OBJECT_FINALIZE"]

  depends_on = [google_project_iam_member.gcs_eventarc_publisher]
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

