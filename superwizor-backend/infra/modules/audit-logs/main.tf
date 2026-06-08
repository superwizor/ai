variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

resource "google_project_iam_audit_config" "all_services" {
  project = var.project_id
  service = "allServices"

  # ADMIN_READ only — free tier, covers IAM/permission changes.
  # DATA_READ + DATA_WRITE REMOVED — on staging they logged every
  # Secret Manager read, KMS decrypt, GCS access, Cloud SQL auth etc.
  # generating ~50-150 PLN/month of Cloud Logging costs with zero
  # diagnostic value. Re-add selectively for specific services when
  # needed for compliance audit.
  audit_log_config {
    log_type = "ADMIN_READ"
  }
}

# ============================================================================
# Cloud Logging exclusion filters — suppress high-volume, low-value logs.
#
# These entries generate thousands of log lines daily with zero diagnostic
# value, costing ~$5-10/month in Cloud Logging ingestion fees. Errors and
# warnings are NEVER excluded — only routine "everything is fine" noise.
# ============================================================================

# 1. Cloud Run health check probes: the Google Frontend pings every
#    revision every few seconds. 200 OK responses are pure noise.
resource "google_logging_project_exclusion" "cloud_run_health_checks" {
  project     = var.project_id
  name        = "cloud-run-health-checks"
  description = "Suppress Cloud Run health check 200s (thousands/day, zero value)"

  filter = <<-EOT
    resource.type="cloud_run_revision"
    httpRequest.requestUrl="/"
    httpRequest.status=200
    httpRequest.userAgent=~"GoogleHC/"
  EOT
}

# 2. Cloud Run startup/shutdown lifecycle logs: "Container called contract"
#    and "Container instance stopped" are routine operational noise.
resource "google_logging_project_exclusion" "cloud_run_lifecycle" {
  project     = var.project_id
  name        = "cloud-run-lifecycle"
  description = "Suppress Cloud Run container start/stop lifecycle messages"

  filter = <<-EOT
    resource.type="cloud_run_revision"
    textPayload=~"^Container called contract|^Default STARTUP TCP probe"
  EOT
}

# 3. Cloud SQL proxy/connection noise: routine auth token refreshes and
#    connection manager pool churn that Cloud SQL Auth Proxy logs at INFO.
resource "google_logging_project_exclusion" "cloudsql_proxy_noise" {
  project     = var.project_id
  name        = "cloudsql-proxy-noise"
  description = "Suppress Cloud SQL proxy routine auth/connection messages"

  filter = <<-EOT
    resource.type="cloud_sql_database"
    severity="INFO"
    textPayload=~"connection stats|cloudsql-proxy"
  EOT
}
