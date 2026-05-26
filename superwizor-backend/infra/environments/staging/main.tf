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
  github_repo = "superwizor/ai"
}

module "audit_logs" {
  source     = "../../modules/audit-logs"
  project_id = var.project_id
}

module "pubsub" {
  source         = "../../modules/pubsub"
  project_id     = var.project_id
  project_number = var.project_number
}

module "storage" {
  source          = "../../modules/storage"
  project_id      = var.project_id
  app_data_key_id = module.kms.app_data_key_id
  # Option F (2026-05-25): re-introduce bucket notification, this
  # time onto its own dedicated topic so ingestion-svc's in-process
  # subscriber is the sole consumer. See modules/pubsub/main.tf and
  # services/ingestion-svc/internal/adapters/pubsub/subscriber.go.
  audio_object_finalized_topic_name = module.pubsub.audio_object_finalized_topic_name

  depends_on = [module.pubsub]
}

module "migrations" {
  source = "../../modules/migrations"

  project_id                  = var.project_id
  db_instance_connection_name = module.cloud_sql.instance_connection_name
  db_url_secret_id            = "postgres-database-url"
  db_user                     = module.cloud_sql.db_user
  db_name                     = module.cloud_sql.db_name
  migrations_dir              = "${path.cwd}/../../../migrations"
  cloud_sql_proxy_path        = "${path.cwd}/../../../cloud-sql-proxy"

  depends_on = [module.cloud_sql]
}

module "cloud_functions" {
  source                         = "../../modules/cloud-functions"
  project_id                     = var.project_id
  region                         = "europe-central2"
  network_id                     = module.vpc.network_id
  db_connection_name             = module.cloud_sql.instance_connection_name
  db_url_secret_id               = "postgres-database-url"
  vpc_connector_id               = module.vpc.vpc_connector_id
  audio_bucket_name              = module.storage.audio_uploads_bucket_name
  transcripts_raw_bucket_name    = module.storage.transcripts_raw_bucket_name
  audio_uploaded_topic           = module.pubsub.audio_uploaded_topic
  transcript_completed_topic     = module.pubsub.transcript_completed_topic
  report_generated_topic         = module.pubsub.report_generated_topic
  session_deleted_topic          = module.pubsub.session_deleted_topic
  billing_outbox_topic           = module.pubsub.billing_outbox_topic
  billing_svc_url                = var.billing_svc_url
  audio_uploaded_dlq_topic       = module.pubsub.audio_uploaded_dlq_topic
  transcript_completed_dlq_topic = module.pubsub.transcript_completed_dlq_topic
  stt_worker_source_dir          = "${path.cwd}/../../../services/ai-pipeline-svc/cmd/stt-worker"
  llm_worker_source_dir          = "${path.cwd}/../../../services/ai-pipeline-svc/cmd/llm-worker"
  notification_worker_source_dir = "${path.cwd}/../../../services/notification-svc"
  stt_worker_sa_email            = google_service_account.stt_worker.email
  llm_worker_sa_email            = google_service_account.llm_worker.email
  notification_worker_sa_email   = google_service_account.notification_svc.email
  app_data_key_id                = module.kms.app_data_key_id
  # PHI exposure: only flip to true for hands-on debugging in staging,
  # and turn back off the moment you're done. Each invocation logs a
  # loud "DEV_LOG_PLAINTEXT_TRANSCRIPT=true" warning — handy as an audit
  # tripwire if it gets left on.
  dev_log_plaintext_transcript = false

  depends_on = [module.cloud_sql, module.storage, module.pubsub, google_service_account.stt_worker, google_service_account.llm_worker, google_service_account.notification_svc, module.kms]
}

# Notification pipeline alerting + dashboard (Sprint 3.6).
#
# Notification channels are intentionally empty for staging — alerts still
# fire to the GCP console; production should populate this with a
# pre-existing channel id (e.g. an email or PagerDuty channel created
# outside this module's lifecycle).
module "monitoring" {
  source     = "../../modules/monitoring"
  project_id = var.project_id

  notification_channels = []

  firestore_sync_dlq_subscription_name = module.pubsub.firestore_sync_dlq_subscription_name

  depends_on = [module.pubsub, module.cloud_functions]
}
