data "google_project" "this" {
  project_id = var.project_id
}

resource "google_service_account" "ingestion_svc" {
  account_id   = "ingestion-svc"
  display_name = "Ingestion Service SA"
  project      = var.project_id
}

# clinical-svc needs its own SA so it can:
#   - read the postgres-database-url secret (cloudsql.client + secretAccessor)
#   - decrypt the report_ciphertext / text_ciphertext columns written by
#     ai-pipeline-svc (cloudkms.cryptoKeyEncrypterDecrypter on app-data-key)
# Without these, GetSessionDetails silently returns an empty Reports list
# because cryptobox.Decrypt errors out and the handler swallows the error.
resource "google_service_account" "clinical_svc" {
  account_id   = "clinical-svc"
  display_name = "Clinical Service SA"
  project      = var.project_id
}

resource "google_service_account" "stt_worker" {
  account_id   = "stt-worker"
  display_name = "STT Worker SA"
  project      = var.project_id
}

resource "google_service_account" "llm_worker" {
  account_id   = "llm-worker"
  display_name = "LLM Worker SA"
  project      = var.project_id
}

resource "google_project_iam_member" "ingestion_signer" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

resource "google_storage_bucket_iam_member" "ingestion_storage" {
  # Zmienione na poprawne odwołanie do bucketu z używanego modułu "storage"
  bucket = module.storage.audio_uploads_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "ingestion_db_pwd" {
  project   = var.project_id
  secret_id = "postgres-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

resource "google_project_iam_member" "ingestion_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

# clinical-svc IAM
resource "google_project_iam_member" "clinical_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.clinical_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "clinical_db_pwd" {
  project   = var.project_id
  secret_id = "postgres-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.clinical_svc.email}"
}

resource "google_kms_crypto_key_iam_member" "clinical_kms" {
  crypto_key_id = module.kms.app_data_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.clinical_svc.email}"
}

# S3: Allow the Pub/Sub service agent to create tokens for worker SAs so Eventarc
# can authenticate invocations with the correct service account identity.
resource "google_service_account_iam_member" "pubsub_sa_stt_token_creator" {
  service_account_id = google_service_account.stt_worker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_service_account_iam_member" "pubsub_sa_llm_token_creator" {
  service_account_id = google_service_account.llm_worker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ============================================================================
# Cloud Run public-invocability for Flutter-facing services.
#
# These services are deployed by CI's `gcloud run deploy --allow-unauthenticated`
# (the service revisions themselves are not yet terraform-managed), but we
# pin the IAM policy here so manual `add-iam-policy-binding` / `remove-iam
# -policy-binding` commands and accidental --no-allow-unauthenticated deploys
# can't quietly break Flutter.
#
# Public at the Cloud Run frontend — the actual user identity is verified
# at the application layer via Firebase ID token (see identity-svc's
# Firebase Admin SDK call paths).
#
# Internal services (billing-svc, ai-pipeline-svc, llm-worker, stt-worker)
# are NOT in this list — they remain SA-bound only.
# ============================================================================
locals {
  public_cloud_run_services = [
    "identity-svc",
    "clinical-svc",
    "ingestion-svc",
    "api-service",
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  for_each = toset(local.public_cloud_run_services)

  project  = var.project_id
  location = "europe-central2"
  name     = each.key
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ============================================================================
# E2E test prerequisite: grant explicit principals the right to call
# `signBlob` on the Firebase Admin SDK service account, which the Firebase
# Admin Go SDK invokes when it falls back from key-based signing to API-based
# signing (i.e., whenever credentials come from ADC rather than a JSON key).
#
# The Firebase Admin SDK SA `firebase-adminsdk-fbsvc@<project>` is auto-
# created by Firebase when the project is provisioned; we only attach IAM
# bindings here, we don't manage its lifecycle.
#
# Members live in `var.e2e_token_minters` (default: empty). Add via tfvars
# or override file rather than editing this list inline:
#
#   e2e_token_minters = [
#     "user:dev1@example.com",
#     "serviceAccount:e2e-runner@${PROJECT_ID}.iam.gserviceaccount.com",
#   ]
# ============================================================================
resource "google_service_account_iam_member" "e2e_firebase_token_creator" {
  for_each = toset(var.e2e_token_minters)

  service_account_id = "projects/${var.project_id}/serviceAccounts/firebase-adminsdk-fbsvc@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.key
}
