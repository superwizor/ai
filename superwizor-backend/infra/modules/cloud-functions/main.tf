# 1. Bucket for storing function source code zips
resource "google_storage_bucket" "functions_source" {
  name                        = "${var.project_id}-functions-src-v2"
  project                     = var.project_id
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true
}

# 1.5 Prepare Go vendor sources
resource "null_resource" "package_functions" {
  triggers = {
    always_run = timestamp()
  }

  provisioner "local-exec" {
    # Przekazujemy ścieżki oraz unikalne ID do skryptu aby mógł utworzyć odpowiednio nazwane pliki zip
    command = "bash ${path.module}/package.sh \"${var.stt_worker_source_dir}\" \"${var.llm_worker_source_dir}\" \"${path.module}\" \"${self.id}\""
  }
}

resource "google_storage_bucket_object" "stt_worker_zip" {
  name   = "stt-worker-${null_resource.package_functions.id}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = "${path.module}/.tmp/stt-worker-${null_resource.package_functions.id}.zip"

  depends_on = [null_resource.package_functions]
}

resource "google_storage_bucket_object" "llm_worker_zip" {
  name   = "llm-worker-${null_resource.package_functions.id}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = "${path.module}/.tmp/llm-worker-${null_resource.package_functions.id}.zip"

  depends_on = [null_resource.package_functions]
}

# 3. Service Accounts for Functions (Passed via variables)
# We assume stt-worker and llm-worker SAs are created outside this module


# stt-worker IAM
resource "google_project_iam_member" "stt_worker_speech" {
  project = var.project_id
  role    = "roles/speech.client"
  member  = "serviceAccount:${var.stt_worker_sa_email}"
}

resource "google_storage_bucket_iam_member" "stt_worker_audio_bucket" {
  bucket = var.audio_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${var.stt_worker_sa_email}"
}

resource "google_project_iam_member" "stt_worker_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.stt_worker_sa_email}"
}

# llm-worker IAM
resource "google_project_iam_member" "llm_worker_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${var.llm_worker_sa_email}"
}

resource "google_project_iam_member" "llm_worker_sql" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${var.llm_worker_sa_email}"
}

# To receive Pub/Sub events via Eventarc, the compute service account or the trigger SA needs permission to invoke Cloud Run. 
# In Gen2, the function's service account acts as the Eventarc trigger identity by default.
resource "google_project_iam_member" "stt_worker_eventarc" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${var.stt_worker_sa_email}"
}

resource "google_project_iam_member" "llm_worker_eventarc" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${var.llm_worker_sa_email}"
}

# 4. Secret Manager access for DB Password
resource "google_secret_manager_secret_iam_member" "stt_worker_db_pwd" {
  project   = var.project_id
  secret_id = var.db_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.stt_worker_sa_email}"
}

resource "google_secret_manager_secret_iam_member" "llm_worker_db_pwd" {
  project   = var.project_id
  secret_id = var.db_password_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.llm_worker_sa_email}"
}

# 5. Cloud Functions Gen2
resource "google_cloudfunctions2_function" "stt_worker" {
  name        = "stt-worker"
  location    = var.region
  project     = var.project_id
  description = "Speech-to-Text Worker (Chirp 3)"

  build_config {
    runtime     = "go122"
    entry_point = "ProcessAudio"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.stt_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "512M"
    timeout_seconds       = 300
    service_account_email = var.stt_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID    = var.project_id
      AUDIO_BUCKET_NAME = var.audio_bucket_name
      DATABASE_URL      = "user=superwizor_app password='$${DB_PASSWORD}' host=/cloudsql/${var.db_connection_name} port=5432 dbname=superwizor"
    }

    secret_environment_variables {
      key        = "DB_PASSWORD"
      project_id = var.project_id
      secret     = var.db_password_secret_id
      version    = "latest"
    }

    # Cloud SQL configuration is handled by Cloud Run under the hood in Gen2 via volumes or vpc
    # Cloud SQL Auth Proxy automatically runs if we specify the connection annotation or use volumes?
    # No, for Gen2 (Cloud Run), we just need to specify the connection. But Terraform google_cloudfunctions2_function doesn't expose it directly.
    # Actually, we can use the VPC connector or just TCP if the DB has public IP.
    # Our DB has public IP, but it's better to use Private IP or the Cloud SQL Unix socket.
    # Let's just use the public IP for staging since authorized networks are configured? 
    # Wait, Cloud Functions IP is dynamic, so it wouldn't be allowed in authorized_networks.
    # We must use VPC access or Cloud Run's native Cloud SQL integration.
    # Cloud SQL native integration in TF google_cloudfunctions2_function is not directly supported, so VPC connector is the standard.
    # But for simplicity, we can pass the DB IP and add a serverless VPC connector.
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = var.audio_uploaded_topic
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY" # Handle retries carefully
    service_account_email = var.stt_worker_sa_email
  }

  depends_on = [
    google_project_iam_member.stt_worker_eventarc,
    google_project_iam_member.stt_worker_speech,
    google_project_iam_member.stt_worker_sql
  ]
}

resource "google_cloudfunctions2_function" "llm_worker" {
  name        = "llm-worker"
  location    = var.region
  project     = var.project_id
  description = "LLM Worker (Gemini 3.1 FLASH)"

  build_config {
    runtime     = "go122"
    entry_point = "ProcessTranscript"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.llm_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 10
    min_instance_count    = 0
    available_memory      = "512M"
    timeout_seconds       = 300
    service_account_email = var.llm_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
      DATABASE_URL   = "user=superwizor_app password='$${DB_PASSWORD}' host=/cloudsql/${var.db_connection_name} port=5432 dbname=superwizor"
    }

    secret_environment_variables {
      key        = "DB_PASSWORD"
      project_id = var.project_id
      secret     = var.db_password_secret_id
      version    = "latest"
    }
  }

  event_trigger {
    trigger_region = var.region
    event_type     = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic   = var.transcript_completed_topic
    retry_policy   = "RETRY_POLICY_DO_NOT_RETRY"
    service_account_email = var.llm_worker_sa_email
  }

  depends_on = [
    google_project_iam_member.llm_worker_eventarc,
    google_project_iam_member.llm_worker_vertex,
    google_project_iam_member.llm_worker_sql
  ]
}
