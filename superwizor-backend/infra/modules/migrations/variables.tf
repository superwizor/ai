variable "project_id" {
  type = string
}

variable "db_instance_connection_name" {
  type        = string
  description = "Cloud SQL instance connection name (project:region:instance)"
}

variable "db_url_secret_id" {
  type        = string
  description = "Secret Manager secret ID storing the full Postgres DSN (postgres://user:pass@host:port/db?sslmode=...). The password is extracted from this URL."
}

variable "db_user" {
  type        = string
  default     = "superwizor_app"
  description = "Postgres user that owns the schema"
}

variable "db_name" {
  type        = string
  default     = "superwizor"
  description = "Postgres database name"
}

variable "migrations_dir" {
  type        = string
  description = "Absolute path to the directory holding *.up.sql / *.down.sql files"
}

variable "cloud_sql_proxy_path" {
  type        = string
  description = "Absolute path to the cloud-sql-proxy binary"
}

variable "proxy_port" {
  type        = number
  default     = 15432
  description = "Local port the cloud-sql-proxy listens on. Picked off the default 5432 to avoid clashing with a developer's local Postgres."
}
