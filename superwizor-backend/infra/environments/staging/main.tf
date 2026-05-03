# module "org_policies" {
#   source     = "../../modules/org-policies"
#   project_id = var.project_id
# }

module "vpc" {
  source     = "../../modules/vpc"
  project_id = var.project_id
}

module "kms" {
  source     = "../../modules/kms"
  project_id = var.project_id
  depends_on = [module.vpc]
}

module "artifact_registry" {
  source     = "../../modules/artifact-registry"
  project_id = var.project_id
}

module "cloud_sql" {
  source       = "../../modules/cloud-sql"
  project_id   = var.project_id
  network_id   = module.vpc.network_id
  kms_key_name = module.kms.database_key_id

  depends_on = [module.vpc, module.kms]
}

module "wif" {
  source      = "../../modules/wif"
  project_id  = var.project_id
  github_repo = "baciok91/superwizor-backend"
}

module "audit_logs" {
  source     = "../../modules/audit-logs"
  project_id = var.project_id
}

module "storage" {
  source          = "../../modules/storage"
  project_id      = var.project_id
  pubsub_topic_id = module.pubsub.audio_uploaded_topic
}

module "pubsub" {
  source     = "../../modules/pubsub"
  project_id = var.project_id
}

module "cloud_functions" {
  source                     = "../../modules/cloud-functions"
  project_id                 = var.project_id
  region                     = "europe-central2"
  network_id                 = module.vpc.network_id
  db_connection_name         = module.cloud_sql.instance_connection_name
  db_password_secret_id      = "superwizor-db-password"
  audio_bucket_name          = module.storage.audio_uploads_bucket_name
  audio_uploaded_topic       = module.pubsub.audio_uploaded_topic
  transcript_completed_topic = module.pubsub.transcript_completed_topic
  stt_worker_source_dir      = "${path.cwd}/../../../services/ai-pipeline-svc/cmd/stt-worker"
  llm_worker_source_dir      = "${path.cwd}/../../../services/ai-pipeline-svc/cmd/llm-worker"
  stt_worker_sa_email        = google_service_account.stt_worker.email
  llm_worker_sa_email        = google_service_account.llm_worker.email

  depends_on = [module.cloud_sql, module.storage, module.pubsub, google_service_account.stt_worker, google_service_account.llm_worker]
}
