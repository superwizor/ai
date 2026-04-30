resource "random_id" "db_name_suffix" {
  byte_length = 4
}

resource "google_sql_database_instance" "main" {
  name             = "superwizor-db-${random_id.db_name_suffix.hex}"
  database_version = "POSTGRES_16"
  region           = "europe-central2"
  project          = var.project_id

  # Deletion protection is typically enabled in production, but we keep it
  # disabled or dependent on the environment for easy tear-down during FAZA 0
  deletion_protection = false

  encryption_key_name = var.kms_key_name

  settings {
    edition = "ENTERPRISE"
    tier    = "db-f1-micro" # Minimal for staging/faza 0

    ip_configuration {
      ipv4_enabled    = true
      private_network = var.network_id

      authorized_networks {
        name  = "local-machine"
        value = "37.47.79.164/32"
      }
    }

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
    }
  }
}

resource "google_sql_database" "app_db" {
  name     = "superwizor"
  instance = google_sql_database_instance.main.name
  project  = var.project_id
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "db_password" {
  project   = var.project_id
  secret_id = "superwizor-db-password"

  replication {
    user_managed {
      replicas {
        location = "europe-central2"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "db_password" {
  secret      = google_secret_manager_secret.db_password.id
  secret_data = random_password.db_password.result
}

resource "google_sql_user" "app_user" {
  name     = "superwizor_app"
  instance = google_sql_database_instance.main.name
  project  = var.project_id
  password = random_password.db_password.result
}

output "instance_name" {
  value = google_sql_database_instance.main.name
}

output "instance_connection_name" {
  value = google_sql_database_instance.main.connection_name
}
