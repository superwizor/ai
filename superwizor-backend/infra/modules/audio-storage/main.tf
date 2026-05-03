variable "project_id" { type = string }
variable "audio_key_id" { type = string }

resource "google_storage_bucket" "audio_uploads" {
  name          = "${var.project_id}-audio-uploads"
  project       = var.project_id
  location      = "EUROPE-CENTRAL2"
  force_destroy = false

  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  encryption {
    default_kms_key_name = var.audio_key_id
  }

  versioning {
    enabled = false  # audio files są tymczasowe — wersjonowanie nie ma sensu
  }

  lifecycle_rule {
    condition {
      age = 2  # 48h
    }
    action {
      type = "Delete"
    }
  }

  cors {
    origin          = ["*"]  # Restrict to mobile app schema if possible, but signed URLs often use *
    method          = ["PUT", "OPTIONS"]
    response_header = ["Content-Type", "x-goog-content-length-range"]
    max_age_seconds = 3600
  }
}

output "bucket_name" {
  value = google_storage_bucket.audio_uploads.name
}
