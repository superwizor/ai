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

variable "app_data_key_id" {
  type        = string
  description = "KMS key ID for app data encryption"
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

resource "google_project_iam_member" "stt_worker_pubsub" {
  project = var.project_id
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:${var.stt_worker_sa_email}"
}

resource "google_kms_crypto_key_iam_member" "stt_worker_kms" {
  crypto_key_id = var.app_data_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.stt_worker_sa_email}"
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

resource "google_kms_crypto_key_iam_member" "llm_worker_kms" {
  crypto_key_id = var.app_data_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${var.llm_worker_sa_email}"
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
  secret_id = var.db_url_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.stt_worker_sa_email}"
}

resource "google_secret_manager_secret_iam_member" "llm_worker_db_pwd" {
  project   = var.project_id
  secret_id = var.db_url_secret_id
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
      KMS_KEY_URI       = var.app_data_key_id
    }

    secret_environment_variables {
      key        = "DATABASE_URL"
      project_id = var.project_id
      secret     = var.db_url_secret_id
      version    = "latest"
    }

    vpc_connector                 = var.vpc_connector_id
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
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
    google_project_iam_member.stt_worker_sql,
    google_kms_crypto_key_iam_member.stt_worker_kms
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
      KMS_KEY_URI    = var.app_data_key_id
    }

    secret_environment_variables {
      key        = "DATABASE_URL"
      project_id = var.project_id
      secret     = var.db_url_secret_id
      version    = "latest"
    }

    vpc_connector                 = var.vpc_connector_id
    vpc_connector_egress_settings = "PRIVATE_RANGES_ONLY"
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

resource "google_cloud_run_service_iam_member" "stt_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.stt_worker.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.stt_worker_sa_email}"
}

resource "google_cloud_run_service_iam_member" "llm_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.llm_worker.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.llm_worker_sa_email}"
}
