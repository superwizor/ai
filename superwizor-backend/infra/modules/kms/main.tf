variable "project_id" { type = string }

variable "keyring_name" {
  type    = string
  default = "superwizor-keyring"
}

resource "google_kms_key_ring" "main" {
  name     = var.keyring_name
  project  = var.project_id
  location = "europe-central2"
}

# Klucz dla bucketu audio
resource "google_kms_crypto_key" "audio_bucket" {
  name            = "audio-bucket-key"
  key_ring        = google_kms_key_ring.main.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s" # 90 dni

  lifecycle {
    prevent_destroy = true
  }
}

# Klucz dla Cloud SQL
resource "google_kms_crypto_key" "database" {
  name            = "database-key"
  key_ring        = google_kms_key_ring.main.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

# Klucz dla Secret Manager
resource "google_kms_crypto_key" "secrets" {
  name            = "secrets-key"
  key_ring        = google_kms_key_ring.main.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

# Klucz aplikacyjny (envelope encryption dla PHI)
resource "google_kms_crypto_key" "app_data" {
  name            = "app-data-key"
  key_ring        = google_kms_key_ring.main.id
  purpose         = "ENCRYPT_DECRYPT"
  rotation_period = "7776000s"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_project_service_identity" "gcp_sa_cloud_sql" {
  provider = google-beta
  project  = var.project_id
  service  = "sqladmin.googleapis.com"
}

data "google_storage_project_service_account" "gcs_account" {
  project = var.project_id
}

resource "google_kms_crypto_key_iam_member" "cloud_sql_kms" {
  crypto_key_id = google_kms_crypto_key.database.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_project_service_identity.gcp_sa_cloud_sql.email}"
}

resource "google_kms_crypto_key_iam_member" "storage_kms" {
  crypto_key_id = google_kms_crypto_key.audio_bucket.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.gcs_account.email_address}"
}

output "keyring_id" { value = google_kms_key_ring.main.id }
output "audio_key_id" { value = google_kms_crypto_key.audio_bucket.id }
output "database_key_id" { value = google_kms_crypto_key.database.id }
output "secrets_key_id" { value = google_kms_crypto_key.secrets.id }
output "app_data_key_id" { value = google_kms_crypto_key.app_data.id }
