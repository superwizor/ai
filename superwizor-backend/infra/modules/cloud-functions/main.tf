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
    # Skrypt korzysta z $REPO_DIR (auto-resolved) by znaleźć wszystkie 3 worker'y;
    # pierwsze dwa argumenty zachowane dla wstecznej kompatybilności sprintów <3.3.
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

# Single source bundle, three Cloud Functions reuse it (one per Pub/Sub
# trigger). Cloud Functions Gen2 = 1 entrypoint per function, so we deploy
# three resources rather than one multi-trigger function.
resource "google_storage_bucket_object" "notification_worker_zip" {
  name   = "notification-worker-${null_resource.package_functions.id}.zip"
  bucket = google_storage_bucket.functions_source.name
  source = "${path.module}/.tmp/notification-worker-${null_resource.package_functions.id}.zip"

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
    runtime     = "go126"
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
    available_memory      = "1Gi"
    available_cpu         = "1"
    timeout_seconds       = 540
    service_account_email = var.stt_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID    = var.project_id
      AUDIO_BUCKET_NAME = var.audio_bucket_name
      KMS_KEY_URI       = var.app_data_key_id
      # PHI exposure: when "true", logs the full plaintext transcript
      # to Cloud Logging. Staging-only debugging; never set on prod.
      DEV_LOG_PLAINTEXT_TRANSCRIPT = var.dev_log_plaintext_transcript ? "true" : "false"
      # Operator opt-in for native Chirp 3 diarization. When "on", AND
      # the session's language is true in
      # transcriptfmt.Chirp3DiarizationLanguages, stt-worker enables
      # SpeakerDiarizationConfig on the BatchRecognize call → words
      # come back with speaker_tag populated → llm-worker takes the
      # role-only-grammar branch instead of clustering.
      # Today: en-US is the only language flagged true; pl-PL stays
      # on the LLM-clustering path. Rollback: change to "off".
      STT_NATIVE_DIARIZATION = "on"
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
    retry_policy   = "RETRY_POLICY_RETRY"
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
  description = "LLM Worker (Gemini 2.5 PRO)"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessTranscript"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.llm_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 5
    min_instance_count    = 0
    available_memory      = "2Gi"
    available_cpu         = "1"
    timeout_seconds       = 540
    service_account_email = var.llm_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
      KMS_KEY_URI    = var.app_data_key_id
      # LLM_DIARIZATION_MODE: "json" (default in code) or "markdown".
      # "markdown" switches call 1 to free-form Markdown output parsed
      # server-side by internal/diarization. Call 2 is ALWAYS Format B
      # speaker-turn Markdown input regardless of this flag.
      # Rollback: change to "json" + re-apply (no rebuild needed,
      # terraform updates the env var in place in ~30s).
      LLM_DIARIZATION_MODE = "markdown"
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
    retry_policy   = "RETRY_POLICY_RETRY"
    service_account_email = var.llm_worker_sa_email
  }

  depends_on = [
    google_project_iam_member.llm_worker_eventarc,
    google_project_iam_member.llm_worker_vertex,
    google_project_iam_member.llm_worker_sql,
    google_kms_crypto_key_iam_member.llm_worker_kms
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

# DLQ pull subscriptions — for monitoring and manual replay of dead-lettered messages
resource "google_pubsub_subscription" "stt_worker_dlq_reader" {
  name    = "stt-worker-dlq-reader"
  project = var.project_id
  topic   = var.audio_uploaded_dlq_topic

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days

  expiration_policy {
    ttl = ""
  }
}

resource "google_pubsub_subscription" "llm_worker_dlq_reader" {
  name    = "llm-worker-dlq-reader"
  project = var.project_id
  topic   = var.transcript_completed_dlq_topic

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days

  expiration_policy {
    ttl = ""
  }
}

# ============================================================================
# notification-svc workers (Phase 3, Sprints 3.3 + 3.5)
#
# Three Cloud Functions Gen2, one shared source bundle. Each binds to its
# own Eventarc Pub/Sub trigger. The notification-svc SA (created in
# environments/staging/service-accounts.tf) is the runtime identity for all
# three; the IAM bindings it needs (datastore.user, fcm sender, eventarc
# receiver, sql client, secret accessor) are also created in that file —
# we don't duplicate them here.
# ============================================================================

# 1) on-uploaded: status mirror only, no FCM. Lightweight.
resource "google_cloudfunctions2_function" "notification_worker_on_uploaded" {
  name        = "notification-worker-on-uploaded"
  location    = var.region
  project     = var.project_id
  description = "Mirrors audio.uploaded → Firestore session_states.status='uploaded'"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessAudioUploaded"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.notification_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 5
    min_instance_count    = 0
    available_memory      = "256Mi"
    available_cpu         = "1"
    timeout_seconds       = 60
    service_account_email = var.notification_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
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
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.audio_uploaded_topic
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.notification_worker_sa_email
  }
}

# 2) on-transcribed: status mirror only, no FCM.
resource "google_cloudfunctions2_function" "notification_worker_on_transcribed" {
  name        = "notification-worker-on-transcribed"
  location    = var.region
  project     = var.project_id
  description = "Mirrors transcript.completed → Firestore session_states.status='analyzing'"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessTranscriptCompleted"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.notification_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 5
    min_instance_count    = 0
    available_memory      = "256Mi"
    available_cpu         = "1"
    timeout_seconds       = 60
    service_account_email = var.notification_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
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
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.transcript_completed_topic
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.notification_worker_sa_email
  }
}

# 3) on-report: full fan-out — FCM push + Firestore done + inbox doc.
# Slightly more memory because the Firebase Admin SDK + Firestore client
# both load on first invocation.
resource "google_cloudfunctions2_function" "notification_worker_on_report" {
  name        = "notification-worker-on-report"
  location    = var.region
  project     = var.project_id
  description = "report.generated → FCM push + Firestore session_states.status='done' + inbox doc"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessReportGenerated"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.notification_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 5
    min_instance_count    = 0
    available_memory      = "512Mi"
    available_cpu         = "1"
    timeout_seconds       = 120
    service_account_email = var.notification_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
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
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.report_generated_topic
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.notification_worker_sa_email
  }
}

# 4) on-deleted: hard-delete cleanup — wipes session_states/{id} and
# inbox notifications referencing the gone session. Triggered by
# clinical-svc's session.deleted Pub/Sub publishes. Light memory like
# the status-mirror workers; the only heavy thing is the CollectionGroup
# query for inbox cleanup, which Firestore evaluates server-side.
resource "google_cloudfunctions2_function" "notification_worker_on_deleted" {
  name        = "notification-worker-on-deleted"
  location    = var.region
  project     = var.project_id
  description = "Cleans Firestore session_states + inbox notifications when a session is hard-deleted"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessSessionDeleted"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.notification_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 5
    min_instance_count    = 0
    available_memory      = "256Mi"
    available_cpu         = "1"
    timeout_seconds       = 60
    service_account_email = var.notification_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID = var.project_id
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
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.session_deleted_topic
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.notification_worker_sa_email
  }
}

# Cloud Run invoker bindings — Cloud Functions Gen2 == Cloud Run under the
# hood; the trigger SA needs run.invoker on its own service.
resource "google_cloud_run_service_iam_member" "notification_on_uploaded_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.notification_worker_on_uploaded.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.notification_worker_sa_email}"
}

resource "google_cloud_run_service_iam_member" "notification_on_transcribed_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.notification_worker_on_transcribed.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.notification_worker_sa_email}"
}

resource "google_cloud_run_service_iam_member" "notification_on_report_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.notification_worker_on_report.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.notification_worker_sa_email}"
}

resource "google_cloud_run_service_iam_member" "notification_on_deleted_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.notification_worker_on_deleted.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.notification_worker_sa_email}"
}
