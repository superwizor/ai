resource "google_service_account" "ingestion_svc" {
  account_id   = "ingestion-svc"
  display_name = "Ingestion Service SA"
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
