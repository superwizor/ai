# =============================================================================
# Monitoring module — Phase 3 (Sprint 3.6) — notification pipeline alerts +
# logging dashboard.
#
# Three alert policies:
#   1. firestore-sync.dlq has undelivered messages         (best-effort visibility)
#   2. notification-worker-on-report error rate elevated   (FCM bugs / Firebase outage)
#   3. notification-svc Cloud Run error rate elevated      (gRPC handler bugs)
#
# Plus a Cloud Logging dashboard with three widgets that visualise:
#   - per-status timeline of recent sessions
#   - FCM success rate
#   - Token invalidation rate
#
# Notification channel(s) are passed in via var.notification_channels (a list
# of channel resource names, e.g. an email channel managed elsewhere). Pass
# an empty list to provision policies without firing — useful for staging
# until the on-call rotation is wired up.
# =============================================================================

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "notification_channels" {
  type        = list(string)
  default     = []
  description = "Notification channel IDs (e.g. projects/X/notificationChannels/Y) attached to every alert policy. Empty = no channels (policies still fire and show in console)."
}

variable "firestore_sync_dlq_subscription_name" {
  type        = string
  description = "Short name of the firestore-sync.dlq pull subscription (used in metric filters)."
}

# ---------------------------------------------------------------------------
# Alert 1: Firestore sync DLQ has anything in it.
# ---------------------------------------------------------------------------
# Rationale: Per ADR-IMPL-009, Firestore writes are best-effort. A non-empty
# DLQ means session_states / inbox docs are silently failing — Flutter loses
# its live update path. This is "alert and investigate", not "page".
resource "google_monitoring_alert_policy" "firestore_sync_dlq_nonempty" {
  display_name = "[notif] firestore-sync.dlq has undelivered messages"
  project      = var.project_id
  combiner     = "OR"

  documentation {
    content   = <<-EOT
      The notification-svc worker forwards failed Firestore writes to the
      firestore-sync.dlq subscription. Any message here means a session_state
      or inbox doc did NOT make it to Firestore — Flutter falls back to
      polling clinical-svc for status, but live updates stop.

      Triage:
      1. `gcloud pubsub subscriptions pull firestore-sync-dlq-reader \
            --project=${var.project_id} --auto-ack=false --limit=5 --format=json`
      2. Check the failure: usually IAM (`roles/datastore.user` missing on
         notification-svc SA) or a malformed doc path.
      3. After fix, replay manually or wait for the next session — the
         current session is unrecoverable.
    EOT
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Undelivered messages > 0 for 10 min"
    condition_threshold {
      filter = join(" AND ", [
        "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\"",
        "resource.type=\"pubsub_subscription\"",
        "resource.labels.subscription_id=\"${var.firestore_sync_dlq_subscription_name}\"",
      ])
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "600s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "604800s" # 7 days
  }
}

# ---------------------------------------------------------------------------
# Alert 2: notification-worker-on-report execution errors elevated.
# ---------------------------------------------------------------------------
# Rationale: this is the only worker that calls FCM. Elevated error rate =
# FCM API outage, Firebase project misconfig, or an actual code bug. We
# care about the on-report function specifically because the other two
# (on-uploaded, on-transcribed) are silent status mirrors and can fail with
# less user impact (clinical-svc poll covers them).
resource "google_monitoring_alert_policy" "notification_worker_on_report_errors" {
  display_name = "[notif] notification-worker-on-report error rate > 10%"
  project      = var.project_id
  combiner     = "OR"

  documentation {
    content   = <<-EOT
      Cloud Function `notification-worker-on-report` is failing > 10% of
      invocations over a 15 min window. This is the FCM-sending function;
      its failure means therapists are not getting "Report ready" pushes.

      Common causes:
      - Firebase Admin SDK init failure → check GCP_PROJECT_ID env on the function
      - SA missing `roles/firebasecloudmessaging.messagesSender`
      - Postgres pool exhausted / DB unavailable
      - Schema mismatch on notification_deliveries idempotency_key

      Logs: `gcloud logging read \
        'resource.labels.service_name="notification-worker-on-report" AND severity>=ERROR' \
        --project=${var.project_id} --limit=20`
    EOT
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "Cloud Functions execution status != ok ratio > 10%"
    condition_monitoring_query_language {
      # MQL note: `0.0` (not `0`) — MQL is strict about Int vs Double in
      # if() branches. With `0` the API returns:
      #   "Operands of 'if' do not have same type: 'Double' and 'Int'."
      query    = <<-EOQ
        fetch cloud_function
        | metric 'cloudfunctions.googleapis.com/function/execution_count'
        | filter (resource.function_name == 'notification-worker-on-report')
        | align rate(5m)
        | every 1m
        | group_by [metric.status],
            [row_count: row_count(),
             total: sum(value.execution_count)]
        | group_by 1m,
            [error_ratio: sum(if(metric.status != 'ok', total, 0.0)) / sum(total)]
        | condition error_ratio > 0.1
      EOQ
      duration = "900s" # 15 min
      trigger {
        count = 1
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "604800s"
  }
}

# ---------------------------------------------------------------------------
# Alert 3: notification-svc Cloud Run error rate elevated.
# ---------------------------------------------------------------------------
# Rationale: Cloud Run handler bugs (RegisterFCMToken / RemoveFCMToken).
# These are user-facing — failure means the Flutter login flow doesn't
# register the device, and the user never gets pushes.
resource "google_monitoring_alert_policy" "notification_svc_5xx" {
  display_name = "[notif] notification-svc 5xx rate > 5%"
  project      = var.project_id
  combiner     = "OR"

  documentation {
    content   = <<-EOT
      Cloud Run service `notification-svc` is returning 5xx for > 5% of
      requests over 15 min. Flutter login / token-refresh flows are
      affected — users register but never get pushes.

      Common causes:
      - DATABASE_URL secret missing / rotated
      - VPC connector down (no route to Cloud SQL)
      - GCP_PROJECT_ID env missing → Firebase Admin Auth init fails →
        every request returns Unauthenticated (treated as 5xx by gRPC)

      Logs: `gcloud logging read \
        'resource.labels.service_name="notification-svc" AND severity>=ERROR' \
        --project=${var.project_id} --limit=20`
    EOT
    mime_type = "text/markdown"
  }

  conditions {
    display_name = "5xx ratio > 5%"
    condition_monitoring_query_language {
      query    = <<-EOQ
        fetch cloud_run_revision
        | metric 'run.googleapis.com/request_count'
        | filter (resource.service_name == 'notification-svc')
        | align rate(5m)
        | every 1m
        | group_by 1m,
            [err_ratio:
              sum(if(metric.response_code_class == '5xx', value.request_count, 0.0))
              /
              sum(value.request_count)]
        | condition err_ratio > 0.05
      EOQ
      duration = "900s"
      trigger {
        count = 1
      }
    }
  }

  notification_channels = var.notification_channels

  alert_strategy {
    auto_close = "604800s"
  }
}

# ---------------------------------------------------------------------------
# Logging dashboard — "Notification pipeline"
# ---------------------------------------------------------------------------
# Three widgets sketching the operational picture:
#   1. Per-status session timeline       (LLM/STT worker logs)
#   2. FCM SendEachForMulticast outcomes (notification-worker-on-report logs)
#   3. Token invalidations               (notification-worker logs, jsonPayload.msg)
#
# The dashboard is JSON because the Terraform resource takes the GCP raw
# format. Edits via the console will be overwritten on next apply — keep
# changes here.
resource "google_monitoring_dashboard" "notification_pipeline" {
  project = var.project_id

  dashboard_json = jsonencode({
    displayName = "Notification pipeline"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 12
          height = 4
          widget = {
            title = "Session status transitions (last hour)"
            logsPanel = {
              filter = join("\n", [
                "resource.type=\"cloud_function\"",
                "resource.labels.function_name=~\"notification-worker-.*\"",
                "jsonPayload.msg=~\"status mirror written|report.generated handled\"",
              ])
              resourceNames = ["projects/${var.project_id}"]
            }
          }
        },
        {
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "notification-worker-on-report executions by status"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"cloudfunctions.googleapis.com/function/execution_count\"",
                      "resource.label.function_name=\"notification-worker-on-report\"",
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.status"]
                    }
                  }
                }
                plotType = "STACKED_AREA"
              }]
            }
          }
        },
        {
          xPos   = 6
          yPos   = 4
          width  = 6
          height = 4
          widget = {
            title = "Token invalidations (NotRegistered / Unregistered)"
            logsPanel = {
              filter = join("\n", [
                "resource.type=\"cloud_function\"",
                "resource.labels.function_name=\"notification-worker-on-report\"",
                "jsonPayload.msg=\"invalidating fcm token\"",
              ])
              resourceNames = ["projects/${var.project_id}"]
            }
          }
        },
        {
          yPos   = 8
          width  = 12
          height = 4
          widget = {
            title = "notification-svc Cloud Run requests"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = join(" AND ", [
                      "metric.type=\"run.googleapis.com/request_count\"",
                      "resource.label.service_name=\"notification-svc\"",
                    ])
                    aggregation = {
                      alignmentPeriod    = "60s"
                      perSeriesAligner   = "ALIGN_RATE"
                      crossSeriesReducer = "REDUCE_SUM"
                      groupByFields      = ["metric.label.response_code_class"]
                    }
                  }
                }
                plotType = "STACKED_BAR"
              }]
            }
          }
        },
      ]
    }
  })
}

output "alert_policy_ids" {
  value = [
    google_monitoring_alert_policy.firestore_sync_dlq_nonempty.id,
    google_monitoring_alert_policy.notification_worker_on_report_errors.id,
    google_monitoring_alert_policy.notification_svc_5xx.id,
  ]
  description = "All three alert policy IDs — useful to pin on dashboards or runbooks."
}

output "dashboard_id" {
  value = google_monitoring_dashboard.notification_pipeline.id
}
