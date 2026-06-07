resource "google_bigquery_dataset" "analytics" {
  project                     = var.project_id
  dataset_id                  = "analytics"
  friendly_name               = "Analytics Dataset"
  description                 = "Contains application and product analytics events"
  location                    = "europe-central2"
  default_table_expiration_ms = null # keep data forever (free tier is 10GB total, which is years for us)
}

resource "google_logging_project_sink" "analytics" {
  project                = var.project_id
  name                   = "analytics-log-sink"
  destination            = "bigquery.googleapis.com/projects/${var.project_id}/datasets/${google_bigquery_dataset.analytics.dataset_id}"
  filter                 = "jsonPayload.ae:*"
  unique_writer_identity = true
}

resource "google_project_iam_member" "logging_bigquery" {
  project = var.project_id
  role    = "roles/bigquery.dataEditor"
  member  = google_logging_project_sink.analytics.writer_identity
}

data "google_secret_manager_secret_version" "db_url" {
  secret  = "postgres-database-url"
  project = var.project_id
}

locals {
  # Extract password from postgres://user:password@host:port/dbname
  db_password = regex("postgres://[^:]+:([^@]+)@", data.google_secret_manager_secret_version.db_url.secret_data)[0]
}

resource "google_bigquery_connection" "cloud_sql" {
  project       = var.project_id
  connection_id = "cloud_sql_conn"
  location      = "europe-central2"
  friendly_name = "Cloud SQL Federation Connection"
  description   = "Read-only connection to Cloud SQL PostgreSQL database"

  cloud_sql {
    instance_id = "${var.project_id}:europe-central2:${var.cloud_sql_instance_name}"
    database    = var.db_name
    type        = "POSTGRES"
    credential {
      username = var.db_user
      password = local.db_password
    }
  }
}

resource "google_pubsub_topic" "analytics_events" {
  project = var.project_id
  name    = "analytics.events"
}

resource "google_pubsub_topic_iam_member" "clinical_analytics_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.analytics_events.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:clinical-svc@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_bigquery_table" "analytics_events" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = "analytics_events"
  deletion_protection = false

  schema = <<EOF
[
  {"name": "event_name", "type": "STRING", "mode": "REQUIRED"},
  {"name": "therapist_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "organization_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "session_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "patient_file_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "report_id", "type": "STRING", "mode": "NULLABLE"},
  {"name": "properties", "type": "JSON", "mode": "NULLABLE"},
  {"name": "source", "type": "STRING", "mode": "REQUIRED"},
  {"name": "client_platform", "type": "STRING", "mode": "NULLABLE"},
  {"name": "client_version", "type": "STRING", "mode": "NULLABLE"},
  {"name": "occurred_at", "type": "TIMESTAMP", "mode": "REQUIRED"}
]
EOF
}

resource "google_bigquery_table_iam_member" "pubsub_bq_editor" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = google_bigquery_table.analytics_events.table_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_bigquery_table_iam_member" "pubsub_bq_viewer" {
  project    = var.project_id
  dataset_id = google_bigquery_dataset.analytics.dataset_id
  table_id   = google_bigquery_table.analytics_events.table_id
  role       = "roles/bigquery.metadataViewer"
  member     = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_subscription" "analytics_bq" {
  project = var.project_id
  name    = "analytics.events.bq"
  topic   = google_pubsub_topic.analytics_events.name

  bigquery_config {
    table                 = "${var.project_id}:${google_bigquery_dataset.analytics.dataset_id}.${google_bigquery_table.analytics_events.table_id}"
    use_table_schema      = true
    write_metadata        = false
    drop_unknown_fields = true
  }

  depends_on = [
    google_bigquery_table_iam_member.pubsub_bq_editor,
    google_bigquery_table_iam_member.pubsub_bq_viewer
  ]
}

