variable "project_id" {
  type        = string
  description = "The GCP project ID"
}

variable "cloud_sql_instance_name" {
  type        = string
  description = "The Cloud SQL instance name"
  default     = ""
}

variable "db_name" {
  type        = string
  description = "The Cloud SQL database name"
  default     = ""
}

variable "db_user" {
  type        = string
  description = "The Cloud SQL database user"
  default     = ""
}

variable "project_number" {
  type        = string
  description = "The GCP project number"
}

