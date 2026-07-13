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
  # objectUser (get + list + create + delete), NOT objectViewer: stt-finalize
  # deletes the source audio right after the transcript is persisted
  # (finalize.go::deleteSessionAudio, shrinks PHI exposure from the 48 h
  # lifecycle to seconds). Least-privilege — objectUser omits the object
  # IAM-admin verbs that objectAdmin carries.
  role   = "roles/storage.objectUser"
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
    max_instance_count = 10
    min_instance_count = 0
    available_memory   = "1Gi"
    available_cpu      = "1"
    # 120s — reverted from the 1800s band-aid (commit on 2026-05-22)
    # now that BatchRecognize uses GcsOutputConfig and stt-submit
    # returns in ~5s without waiting on Chirp. The 540s timeout
    # exceeded that was the symptom of the inline-output coupling
    # this branch removes. See
    # docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md Stage 1.
    timeout_seconds       = 120
    service_account_email = var.stt_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID    = var.project_id
      AUDIO_BUCKET_NAME = var.audio_bucket_name
      # Destination prefix for Chirp BatchRecognize output (Stage 1).
      # stt-submit writes GcsOutputConfig.Uri = gs://${TRANSCRIPTS_RAW_BUCKET}/{sid}/chunk_{i}/
      # and OBJECT_FINALIZE on this bucket triggers stt-finalize.
      TRANSCRIPTS_RAW_BUCKET = var.transcripts_raw_bucket_name
      KMS_KEY_URI            = var.app_data_key_id
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
      # billing-svc URL for fire-and-forget CommitUsage after STT
      # finalize. Set via var.billing_svc_url (Phase 3, slice 5). Empty
      # = billing hook disabled.
      BILLING_SVC_URL = var.billing_svc_url
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
    max_instance_count    = 10
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
    trigger_region        = var.region
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = var.transcript_completed_topic
    retry_policy          = "RETRY_POLICY_RETRY"
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
# stt-finalize + stt-watchdog (Stage 1 of feat/stt-long_audio_support)
#
# Both functions share the SAME source zip as stt-worker — they live
# in package sttworker (cmd/stt-worker/) and register entry points
# via init():
#   - ProcessAudio (existing)        → stt-worker (the original
#                                       Pub/Sub-triggered submit)
#   - ProcessTranscriptObject (new)  → stt-finalize (Storage
#                                       OBJECT_FINALIZE-triggered)
#   - ProcessWatchdog (new)          → stt-watchdog (HTTP-triggered)
#
# Per Open Q4 resolution in docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md.
# ============================================================================

# IAM: stt-worker SA needs to write into transcripts-raw (it sets
# GcsOutputConfig.Uri there) AND read from it (stt-finalize). The
# shared SA model means one binding covers all three entry points.
resource "google_storage_bucket_iam_member" "stt_worker_transcripts_raw" {
  bucket = var.transcripts_raw_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${var.stt_worker_sa_email}"
}

# stt-finalize: Eventarc OBJECT_FINALIZE on transcripts-raw bucket.
resource "google_cloudfunctions2_function" "stt_finalize" {
  name        = "stt-finalize"
  location    = var.region
  project     = var.project_id
  description = "Reads Chirp output from GCS, merges chunks, persists transcript"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessTranscriptObject"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.stt_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count = 10
    min_instance_count = 0
    available_memory   = "1Gi"
    available_cpu      = "1"
    # Finalize work: GCS download (~few MB), JSON unmarshal,
    # ParseChirp3Results, chunker, persistTranscript,
    # publishTranscriptCompleted. ~30s p99 for Stage 1 single-chunk;
    # Stage 2 grows to ~60s for 4-chunk sessions. 300s is conservative.
    timeout_seconds       = 300
    service_account_email = var.stt_worker_sa_email

    environment_variables = {
      GCP_PROJECT_ID               = var.project_id
      AUDIO_BUCKET_NAME            = var.audio_bucket_name
      TRANSCRIPTS_RAW_BUCKET       = var.transcripts_raw_bucket_name
      KMS_KEY_URI                  = var.app_data_key_id
      DEV_LOG_PLAINTEXT_TRANSCRIPT = var.dev_log_plaintext_transcript ? "true" : "false"
      STT_NATIVE_DIARIZATION       = "on"
      # billing-svc URL for fire-and-forget CommitUsage. The
      # commitBillingUsageAsync helper lives in finalize.go and runs in
      # this function (entry point ProcessTranscriptObject) — NOT in
      # stt-worker. Without this env var the billing hook stays
      # disabled and usage_events never get a row → counter never
      # increments. Empty default keeps the hook disabled for
      # environments not bootstrapped with billing-svc.
      BILLING_SVC_URL = var.billing_svc_url
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
    event_type     = "google.cloud.storage.object.v1.finalized"
    event_filters {
      attribute = "bucket"
      value     = var.transcripts_raw_bucket_name
    }
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.stt_worker_sa_email
  }

  depends_on = [
    google_project_iam_member.stt_worker_eventarc,
    google_project_iam_member.stt_worker_sql,
    google_kms_crypto_key_iam_member.stt_worker_kms,
    google_storage_bucket_iam_member.stt_worker_transcripts_raw,
  ]
}

resource "google_cloud_run_service_iam_member" "stt_finalize_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.stt_finalize.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.stt_worker_sa_email}"
}

# stt-watchdog: HTTP-triggered, invoked by Cloud Scheduler every 15 min.
resource "google_cloudfunctions2_function" "stt_watchdog" {
  name        = "stt-watchdog"
  location    = var.region
  project     = var.project_id
  description = "Polls stuck stt_operations rows. Recovers when Eventarc dropped OBJECT_FINALIZE."

  build_config {
    runtime     = "go126"
    entry_point = "ProcessWatchdog"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.stt_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 2
    min_instance_count    = 0
    available_memory      = "512Mi"
    available_cpu         = "1"
    timeout_seconds       = 300
    service_account_email = var.stt_worker_sa_email
    # Gated by run.invoker IAM (only stt-worker SA can call it via
    # OIDC); no need for ALLOW_INTERNAL_ONLY ingress restriction
    # which would also block Cloud Scheduler.

    environment_variables = {
      GCP_PROJECT_ID         = var.project_id
      AUDIO_BUCKET_NAME      = var.audio_bucket_name
      TRANSCRIPTS_RAW_BUCKET = var.transcripts_raw_bucket_name
      KMS_KEY_URI            = var.app_data_key_id
      STT_NATIVE_DIARIZATION = "on"
      # Watchdog drives commitBillingUsageAsync when it re-drives a
      # stuck merge (rescueStuckMerges → finalizeIfReady). Without this,
      # watchdog-rescued sessions never bill. Matches stt_finalize.
      BILLING_SVC_URL = var.billing_svc_url
      # Hung-PENDING give-up window: a Chirp op pending this long AND with
      # a stale metadata.update_time is cancelled + re-submitted (bounded
      # by maxChunkRetries). Lowered from the 3h code default to 1h after
      # session 4d18caee sat hung ~1h while update_time was frozen ~56min
      # — the staleness gate already discriminates a hang from queue-wide
      # slowness, so 1h recovers far sooner with little false-positive
      # risk. Pairs with STT_PENDING_STALE_MINUTES (code default 45).
      STT_PENDING_GIVEUP_HOURS = "1"
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
}

resource "google_cloud_run_service_iam_member" "stt_watchdog_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.stt_watchdog.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${var.stt_worker_sa_email}"
}

# Cloud Scheduler hits the watchdog every 15 min. Uses OIDC to
# authenticate as the stt-worker SA (which already has run.invoker on
# the stt_watchdog Cloud Run service via the binding above).
resource "google_cloud_scheduler_job" "stt_watchdog_cron" {
  name        = "stt-watchdog-cron"
  project     = var.project_id
  region      = var.region
  description = "Every 15 min: scan stt_operations for stuck submits"
  schedule    = "*/15 * * * *"
  time_zone   = "Europe/Warsaw"

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.stt_watchdog.service_config[0].uri

    oidc_token {
      service_account_email = var.stt_worker_sa_email
      # Cloud Functions Gen2 verifies the audience claim matches the
      # function's URI.
      audience = google_cloudfunctions2_function.stt_watchdog.service_config[0].uri
    }
  }

  retry_config {
    retry_count          = 1
    min_backoff_duration = "30s"
    max_backoff_duration = "120s"
  }

  depends_on = [
    google_cloud_run_service_iam_member.stt_watchdog_invoker,
  ]
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

# docs/21: consumes session.status_changed → mirrors transcribing /
# failed / cancelled into Firestore session_states. One function for the
# variable-status transitions (the status is carried in the payload).
resource "google_cloudfunctions2_function" "notification_worker_on_status" {
  name        = "notification-worker-on-status"
  location    = var.region
  project     = var.project_id
  description = "Mirrors session.status_changed → Firestore session_states (transcribing/failed/cancelled)"

  build_config {
    runtime     = "go126"
    entry_point = "ProcessSessionStatusChanged"
    source {
      storage_source {
        bucket = google_storage_bucket.functions_source.name
        object = google_storage_bucket_object.notification_worker_zip.name
      }
    }
  }

  service_config {
    max_instance_count    = 2 # was 5 — zero users
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
    pubsub_topic          = var.session_status_changed_topic
    retry_policy          = "RETRY_POLICY_RETRY"
    service_account_email = var.notification_worker_sa_email
  }
}

# notification-worker-on-billing was removed in Phase C of
# feat/billing-svc-refactor. Quota state now propagates via direct RPC
# (clinical-svc.GetMyBillingState + state_after on Reservation /
# UsageCommit responses) — no Pub/Sub fan-out, no Firestore mirror, no
# Cloud Function consumer. See migrations/000034_drop_outbox_events.up.sql
# for the rationale; the billing.outbox topic + DLQ are torn down by
# modules/pubsub.

# on-report RETIRED (docs/21 Faza-4 consolidation): the report-ready FCM
# push + inbox doc it owned moved into ProcessSessionStatusChanged's "done"
# branch (handleReportReady). llm-worker now publishes the terminal-success
# transition to session.status_changed instead of report.generated, so the
# single on-status function carries the whole lifecycle including the push.
# The report.generated topic + its DLQ are torn down in modules/pubsub.

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
    max_instance_count    = 2 # was 5 — zero users
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
resource "google_cloud_run_service_iam_member" "notification_on_status_invoker" {
  location = var.region
  project  = var.project_id
  service  = google_cloudfunctions2_function.notification_worker_on_status.name
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
