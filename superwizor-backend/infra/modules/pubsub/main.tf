variable "project_id" { type = string }

# Project number is needed to construct the Pub/Sub service-agent
# principal (`service-<PROJECT_NUMBER>@gcp-sa-pubsub.iam.gserviceaccount.com`).
# That agent is the one that publishes to the DLQ topic when the main
# subscription exhausts max_delivery_attempts — without explicit
# pubsub.publisher on the DLQ topic, the dead-letter flow silently
# drops messages.
variable "project_number" {
  type        = string
  description = "GCP project number (NOT project_id). Used to bind the Pub/Sub service agent to DLQ topics for dead-letter delivery."
}

# ============================================
# TOPICS
# ============================================
resource "google_pubsub_topic" "audio_uploaded" {
  name    = "audio.uploaded"
  project = var.project_id
}

# Option F (feat/refactor-stt-architecture, 2026-05-25).
# Raw GCS OBJECT_FINALIZE events from the audio-uploads bucket land
# here. ingestion-svc's in-process pull subscriber consumes from
# `audio.objectFinalized.sub` below, runs ffprobe + optional
# transcode + optional chunking, then republishes the structured
# `audio.uploaded` event for downstream STT.
#
# Why a separate topic (not direct routing to audio.uploaded): the
# old google_storage_notification on the audio-uploads bucket used
# to point at audio.uploaded directly, but emitted raw storage#object
# events that no downstream subscriber could parse — causing the
# 2026-05-23 backlog incident that masked monotonic-ordering bugs in
# Firestore writes (see modules/storage/main.tf:41-55). Keeping
# OBJECT_FINALIZE on its own topic makes ingestion-svc the sole
# legitimate publisher of audio.uploaded, preserving the structured
# {session_id, upload_id, object_path} contract downstream workers
# rely on.
resource "google_pubsub_topic" "audio_object_finalized" {
  name    = "audio.objectFinalized"
  project = var.project_id
}

resource "google_pubsub_topic" "audio_object_finalized_dlq" {
  name    = "audio.objectFinalized.dlq"
  project = var.project_id
}

resource "google_pubsub_topic" "transcript_completed" {
  name    = "transcript.completed"
  project = var.project_id
}

resource "google_pubsub_topic" "report_generated" {
  name    = "report.generated"
  project = var.project_id
}

# session.deleted — emitted by clinical-svc.DeleteSession and (per-session)
# by clinical-svc.DeletePatientFile. notification-svc-on-deleted handler
# consumes these to wipe the Firestore session_states/{sessionId} doc and
# any per-user inbox notifications referencing the gone session.
# Best-effort fan-out: clinical-svc logs publish errors but doesn't block
# the gRPC DELETE return. Idempotent consumer — replays are safe.
resource "google_pubsub_topic" "session_deleted" {
  name    = "session.deleted"
  project = var.project_id
}

# session.status_changed (docs/21): unified mirror for the
# currently-unmirrored transitions — transcribing (progress), failed
# (terminal), cancelled (user). Published by ai-pipeline-svc workers and
# clinical-svc; consumed by notification-worker-on-status.
resource "google_pubsub_topic" "session_status_changed" {
  name    = "session.status_changed"
  project = var.project_id
}

# DLQ topics
resource "google_pubsub_topic" "audio_uploaded_dlq" {
  name    = "audio.uploaded.dlq"
  project = var.project_id
}

resource "google_pubsub_topic" "session_status_changed_dlq" {
  name    = "session.status_changed.dlq"
  project = var.project_id
}

resource "google_pubsub_topic" "transcript_completed_dlq" {
  name    = "transcript.completed.dlq"
  project = var.project_id
}

resource "google_pubsub_topic" "session_deleted_dlq" {
  name    = "session.deleted.dlq"
  project = var.project_id
}

# DLQ for the report.generated pipeline (notification-worker-on-report).
# Mirror of audio_uploaded_dlq / transcript_completed_dlq — every main
# topic that has an Eventarc consumer gets a paired DLQ so the
# wire_dlq.sh post-apply script can bind it via
# `gcloud pubsub subscriptions update`.
resource "google_pubsub_topic" "report_generated_dlq" {
  name    = "report.generated.dlq"
  project = var.project_id
}

# ============================================
# DLQ publisher bindings
# ============================================
# When an Eventarc-managed subscription crosses its max_delivery_attempts
# threshold, Pub/Sub itself (acting as the subscription owner) publishes
# the rejected message to the dead-letter topic. The publishing identity
# is the project's Pub/Sub service agent, NOT the consumer's runtime SA.
# Without the bindings below the dead-letter flow silently fails — main
# subscription keeps retrying for the full 24h retention window (the
# exact failure mode documented in docs/agents/TODO.md "Wire DLQ" entry,
# session b6c7a606, 2026-05-14).
locals {
  pubsub_service_agent = "serviceAccount:service-${var.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "pubsub_agent_audio_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.audio_uploaded_dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent
}

resource "google_pubsub_topic_iam_member" "pubsub_agent_transcript_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.transcript_completed_dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent
}

resource "google_pubsub_topic_iam_member" "pubsub_agent_report_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.report_generated_dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent
}

resource "google_pubsub_topic_iam_member" "pubsub_agent_session_deleted_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.session_deleted_dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent
}

resource "google_pubsub_topic_iam_member" "pubsub_agent_session_status_changed_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.session_status_changed_dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent
}

# Option F: Pub/Sub service agent publishes to the audio.objectFinalized
# DLQ when the pull subscriber exhausts max_delivery_attempts.
resource "google_pubsub_topic_iam_member" "pubsub_agent_audio_object_finalized_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.audio_object_finalized_dlq.name
  role    = "roles/pubsub.publisher"
  member  = local.pubsub_service_agent
}

# Pull subscriptions on each DLQ so operators can inspect dead messages
# (`gcloud pubsub subscriptions pull <name> --auto-ack`) without
# attaching a consumer. Mirrors firestore_sync_dlq_reader below — same
# 7-day retention, never expires.
resource "google_pubsub_subscription" "audio_uploaded_dlq_reader" {
  name    = "audio.uploaded.dlq.reader"
  project = var.project_id
  topic   = google_pubsub_topic.audio_uploaded_dlq.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days
  expiration_policy { ttl = "" }
}

resource "google_pubsub_subscription" "transcript_completed_dlq_reader" {
  name    = "transcript.completed.dlq.reader"
  project = var.project_id
  topic   = google_pubsub_topic.transcript_completed_dlq.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  expiration_policy { ttl = "" }
}

resource "google_pubsub_subscription" "report_generated_dlq_reader" {
  name    = "report.generated.dlq.reader"
  project = var.project_id
  topic   = google_pubsub_topic.report_generated_dlq.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  expiration_policy { ttl = "" }
}

resource "google_pubsub_subscription" "session_deleted_dlq_reader" {
  name    = "session.deleted.dlq.reader"
  project = var.project_id
  topic   = google_pubsub_topic.session_deleted_dlq.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s"
  expiration_policy { ttl = "" }
}

# Option F: pull-subscription reader on the audio.objectFinalized DLQ.
# Operator inspection only — mirrors the audio.uploaded.dlq.reader pattern.
resource "google_pubsub_subscription" "audio_object_finalized_dlq_reader" {
  name    = "audio.objectFinalized.dlq.reader"
  project = var.project_id
  topic   = google_pubsub_topic.audio_object_finalized_dlq.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days
  expiration_policy { ttl = "" }
}

# Option F: the primary pull subscription that ingestion-svc's in-process
# subscriber goroutine consumes from. Carries the GCS OBJECT_FINALIZE
# event payload and routes it to handleMessage in
# services/ingestion-svc/internal/adapters/pubsub/subscriber.go.
#
# ack_deadline_seconds = 600 (10 min) because the worst-case handler
# path is ffprobe → download → transcode → upload → silence-detect →
# chunk-write — bounded by the size of a 90-minute audio file.
# Pub/Sub auto-extends the lease while the handler is still running.
#
# max_delivery_attempts = 5 lets transient network blips (Chirp,
# GCS, Cloud SQL) self-heal. Terminal errors (corrupt audio, missing
# session row) are ack'd by the handler itself so they don't burn
# delivery budget.
resource "google_pubsub_subscription" "audio_object_finalized_sub" {
  name    = "audio.objectFinalized.sub"
  project = var.project_id
  topic   = google_pubsub_topic.audio_object_finalized.id

  ack_deadline_seconds       = 600
  message_retention_duration = "604800s" # 7 days
  expiration_policy { ttl = "" }

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic = google_pubsub_topic.audio_object_finalized_dlq.id
    # docs/21 WS0A: 100 attempts at 10–600s backoff ≈ ~24h envelope,
    # matching the Eventarc subs (wire_dlq.sh). Was 5 (~minutes), which
    # gave up on a Chirp/transcripts-raw transient long before it could
    # self-heal. The DLQ give-up reaper surfaces FAILED only after this.
    max_delivery_attempts = 100
  }
}

# Option F: ingestion-svc reads the OBJECT_FINALIZE feed. Without this
# binding, sub.Receive() in subscriber.go returns PERMISSION_DENIED on
# first pull. Subscriber + ack permissions are bundled in the
# `pubsub.subscriber` role.
resource "google_pubsub_subscription_iam_member" "ingestion_subscriber_audio_object_finalized" {
  project      = var.project_id
  subscription = google_pubsub_subscription.audio_object_finalized_sub.name
  role         = "roles/pubsub.subscriber"
  member       = "serviceAccount:ingestion-svc@${var.project_id}.iam.gserviceaccount.com"
}

# DLQ for best-effort Firestore writes from notification-svc worker
# (ADR-IMPL-009). Failed writes get published here so:
#   - alerting policy can fire on undelivered_messages > 0
#   - operators can replay via the pull subscription below
# This NEVER blocks the clinical pipeline — the worker ACKs Pub/Sub even
# when the Firestore write fails (and forwards the message here for
# observability instead).
resource "google_pubsub_topic" "firestore_sync_dlq" {
  name    = "firestore-sync.dlq"
  project = var.project_id
}

resource "google_pubsub_subscription" "firestore_sync_dlq_reader" {
  name    = "firestore-sync-dlq-reader"
  project = var.project_id
  topic   = google_pubsub_topic.firestore_sync_dlq.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days

  expiration_policy {
    ttl = ""
  }
}

# notification-svc may publish to firestore-sync.dlq when a Firestore
# write fails (Phase 4 wiring; for now the worker logs only — the
# binding is here so it's ready when the publish-on-failure code lands).
resource "google_pubsub_topic_iam_member" "notification_firestore_dlq_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.firestore_sync_dlq.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:notification-svc@${var.project_id}.iam.gserviceaccount.com"
}

# ============================================
# SUBSCRIPTIONS — Eventarc/CloudFunctions używają własnych
# (te są dla manual debugging i other consumers)
# ============================================
resource "google_pubsub_subscription" "audio_uploaded_debug" {
  name    = "audio.uploaded.debug"
  project = var.project_id
  topic   = google_pubsub_topic.audio_uploaded.id

  ack_deadline_seconds       = 60
  message_retention_duration = "604800s" # 7 days

  retry_policy {
    minimum_backoff = "10s"
    maximum_backoff = "600s"
  }

  dead_letter_policy {
    dead_letter_topic     = google_pubsub_topic.audio_uploaded_dlq.id
    max_delivery_attempts = 5
  }
}

# IAM: ingestion-svc może publishować
resource "google_pubsub_topic_iam_member" "ingestion_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.audio_uploaded.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:ingestion-svc@${var.project_id}.iam.gserviceaccount.com"
}

# IAM: stt-worker może publishować transcript.completed
resource "google_pubsub_topic_iam_member" "stt_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.transcript_completed.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:stt-worker@${var.project_id}.iam.gserviceaccount.com"
}
# IAM: llm-worker może publishować report.generated
resource "google_pubsub_topic_iam_member" "llm_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.report_generated.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:llm-worker@${var.project_id}.iam.gserviceaccount.com"
}

# IAM: clinical-svc may publish session.deleted (one event per
# DeleteSession + per session under DeletePatientFile fan-out).
# Service account convention: clinical-svc@<project>.iam — created
# elsewhere in the staging/service-accounts terraform.
resource "google_pubsub_topic_iam_member" "clinical_session_deleted_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.session_deleted.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:clinical-svc@${var.project_id}.iam.gserviceaccount.com"
}

# IAM: stt-worker + llm-worker + clinical-svc may publish
# session.status_changed (docs/21). stt-worker covers stt-finalize +
# stt-watchdog (same SA); llm-worker covers terminal report failures;
# clinical-svc publishes "cancelled".
resource "google_pubsub_topic_iam_member" "stt_status_changed_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.session_status_changed.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:stt-worker@${var.project_id}.iam.gserviceaccount.com"
}

# docs/21 Faza-4: ingestion-svc publishes "uploaded" onto the unified
# topic (on-uploaded retired).
resource "google_pubsub_topic_iam_member" "ingestion_status_changed_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.session_status_changed.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:ingestion-svc@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "llm_status_changed_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.session_status_changed.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:llm-worker@${var.project_id}.iam.gserviceaccount.com"
}

resource "google_pubsub_topic_iam_member" "clinical_status_changed_publisher" {
  project = var.project_id
  topic   = google_pubsub_topic.session_status_changed.name
  role    = "roles/pubsub.publisher"
  member  = "serviceAccount:clinical-svc@${var.project_id}.iam.gserviceaccount.com"
}

# Phase C of feat/billing-svc-refactor removed billing.outbox + its DLQ +
# the billing-svc publisher IAM binding. Quota state now propagates via
# direct RPC — clinical-svc.GetMyBillingState plus state_after on
# Reservation / UsageCommit responses — so there is no producer left and
# the notification-worker-on-billing CF consumer is gone. See
# migrations/000034_drop_outbox_events.up.sql for the broader rationale.
#
# terragrunt apply will destroy:
#   - google_pubsub_topic.billing_outbox             (billing.outbox)
#   - google_pubsub_topic.billing_outbox_dlq         (billing.outbox.dlq)
#   - google_pubsub_topic_iam_member.billing_outbox_publisher
#   - google_pubsub_topic_iam_member.pubsub_agent_billing_outbox_dlq_publisher
#   - google_pubsub_subscription.billing_outbox_dlq_reader

output "audio_uploaded_topic" { value = google_pubsub_topic.audio_uploaded.id }
output "audio_object_finalized_topic" { value = google_pubsub_topic.audio_object_finalized.id }
output "audio_object_finalized_topic_name" { value = google_pubsub_topic.audio_object_finalized.name }
output "audio_object_finalized_subscription_id" { value = google_pubsub_subscription.audio_object_finalized_sub.id }
output "audio_object_finalized_subscription_name" { value = google_pubsub_subscription.audio_object_finalized_sub.name }
output "transcript_completed_topic" { value = google_pubsub_topic.transcript_completed.id }
output "report_generated_topic" { value = google_pubsub_topic.report_generated.id }
output "session_deleted_topic" { value = google_pubsub_topic.session_deleted.id }
output "session_status_changed_topic" { value = google_pubsub_topic.session_status_changed.id }
output "session_status_changed_dlq_topic" { value = google_pubsub_topic.session_status_changed_dlq.id }
output "audio_uploaded_dlq_topic" { value = google_pubsub_topic.audio_uploaded_dlq.id }
output "transcript_completed_dlq_topic" { value = google_pubsub_topic.transcript_completed_dlq.id }
output "report_generated_dlq_topic" { value = google_pubsub_topic.report_generated_dlq.id }
output "session_deleted_dlq_topic" { value = google_pubsub_topic.session_deleted_dlq.id }
output "firestore_sync_dlq_topic" { value = google_pubsub_topic.firestore_sync_dlq.id }
output "firestore_sync_dlq_subscription" { value = google_pubsub_subscription.firestore_sync_dlq_reader.id }
output "firestore_sync_dlq_subscription_name" { value = google_pubsub_subscription.firestore_sync_dlq_reader.name }
