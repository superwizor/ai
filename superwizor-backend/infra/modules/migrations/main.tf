locals {
  migration_files = fileset(var.migrations_dir, "*.sql")
  migrations_hash = sha256(join("", [for f in sort(tolist(local.migration_files)) : filesha256("${var.migrations_dir}/${f}")]))
}

resource "null_resource" "run_migrations" {
  triggers = {
    migrations_hash = local.migrations_hash
    instance        = var.db_instance_connection_name
    db_name         = var.db_name
    db_user         = var.db_user
  }

  provisioner "local-exec" {
    command = "${path.module}/run.sh"
    environment = {
      PROJECT_ID         = var.project_id
      DB_CONNECTION_NAME = var.db_instance_connection_name
      DB_URL_SECRET_ID   = var.db_url_secret_id
      DB_USER            = var.db_user
      DB_NAME            = var.db_name
      MIGRATIONS_DIR     = var.migrations_dir
      CLOUD_SQL_PROXY    = var.cloud_sql_proxy_path
      PROXY_PORT         = var.proxy_port
    }
  }
}
