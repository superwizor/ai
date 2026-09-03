# Billing Cloud Scheduler jobs (Phase 3, slice 3).
#
# Reference: docs/16_BILLING_SERVICE_PHASE_3.md §8, §9.
#
# Trzy jobs które wołają HTTP endpointy na billing-svc Cloud Run:
#   - reservation-expiry      → co 5 min   → /admin/reservation-expiry
#   - manual-period-renewal   → daily 00:05 UTC → /admin/manual-period-renewal
#   - safety-check            → weekly Mon 08:00 → /admin/safety-check
#
# Wszystkie używają OIDC z cloud-scheduler-billing@<project>.iam SA.
# IAM binding (roles/run.invoker) zdefiniowany w service-accounts.tf.

locals {
  # billing-svc Cloud Run URI — z `var.billing_svc_url`. Cloud Run services
  # są wdrażane przez CI (nie terraform), więc po pierwszym deployu trzeba
  # podać URL przez tfvars. Empty value = jobs paused (defined below).
  billing_svc_url       = var.billing_svc_url
  billing_crons_enabled = local.billing_svc_url != ""
}

resource "google_cloud_scheduler_job" "billing_reservation_expiry" {
  name        = "billing-reservation-expiry"
  project     = var.project_id
  region      = "europe-central2"
  description = "Phase 3: co 5 min EXPIRED stale reservations (TTL 4h)"
  schedule    = "*/5 * * * *"
  time_zone   = "Europe/Warsaw"
  paused      = !local.billing_crons_enabled

  http_target {
    http_method = "POST"
    uri         = "${local.billing_svc_url}/admin/reservation-expiry"

    oidc_token {
      service_account_email = google_service_account.cloud_scheduler_billing.email
      audience              = local.billing_svc_url
    }
  }

  retry_config {
    retry_count          = 1
    min_backoff_duration = "30s"
    max_backoff_duration = "120s"
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.scheduler_invoke_billing,
  ]
}

resource "google_cloud_scheduler_job" "billing_manual_period_renewal" {
  name        = "billing-manual-period-renewal"
  project     = var.project_id
  region      = "europe-central2"
  description = "Phase 3: daily 00:05 UTC roll over MANUAL provider subscriptions"
  schedule    = "5 0 * * *"
  time_zone   = "UTC"
  paused      = !local.billing_crons_enabled

  http_target {
    http_method = "POST"
    uri         = "${local.billing_svc_url}/admin/manual-period-renewal"

    oidc_token {
      service_account_email = google_service_account.cloud_scheduler_billing.email
      audience              = local.billing_svc_url
    }
  }

  retry_config {
    retry_count          = 2
    min_backoff_duration = "60s"
    max_backoff_duration = "300s"
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.scheduler_invoke_billing,
  ]
}

resource "google_cloud_scheduler_job" "billing_safety_check" {
  name        = "billing-safety-check"
  project     = var.project_id
  region      = "europe-central2"
  description = "Phase 3: weekly Mon 08:00 alert na missing usage_counters"
  schedule    = "0 8 * * 1"
  time_zone   = "Europe/Warsaw"
  paused      = !local.billing_crons_enabled

  http_target {
    http_method = "POST"
    uri         = "${local.billing_svc_url}/admin/safety-check"

    oidc_token {
      service_account_email = google_service_account.cloud_scheduler_billing.email
      audience              = local.billing_svc_url
    }
  }

  retry_config {
    retry_count          = 1
    min_backoff_duration = "60s"
    max_backoff_duration = "300s"
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.scheduler_invoke_billing,
  ]
}

# ── Uzgadnianie subskrypcji sklepowych (docs/70 §7.3, E12) ────────────
#
# Notyfikacje App Store i RTDN Google potrafią się zgubić albo spóźnić, a
# wtedy uprawnienie w naszej bazie rozjeżdża się ze stanem w sklepie —
# najczęściej na naszą niekorzyść (odnowienie, o którym nie wiemy) albo na
# niekorzyść użytkownika (wygaśnięcie, którego nie odnotowaliśmy).
#
# Ten cron raz na dobę bierze subskrypcje sklepowe, którym minął okres lub
# okno łaski, i pyta sklep, co się z nimi naprawdę stało. Notyfikacja jest
# sygnałem, API sklepu jest prawdą.
#
# Godzina: 03:15 UTC — po dobowym oknie odnowień Apple'a i przed
# porannymi raportami.
resource "google_cloud_scheduler_job" "billing_store_reconcile" {
  name        = "billing-store-reconcile"
  project     = var.project_id
  region      = "europe-central2"
  description = "docs/70: dobowe uzgodnienie subskrypcji App Store / Google Play ze stanem w sklepie"
  schedule    = "15 3 * * *"
  time_zone   = "UTC"
  paused      = !local.billing_crons_enabled

  http_target {
    http_method = "POST"
    uri         = "${local.billing_svc_url}/admin/store-reconcile"

    oidc_token {
      service_account_email = google_service_account.cloud_scheduler_billing.email
      audience              = local.billing_svc_url
    }
  }

  retry_config {
    retry_count          = 2
    min_backoff_duration = "60s"
    max_backoff_duration = "300s"
  }

  depends_on = [
    google_cloud_run_v2_service_iam_member.scheduler_invoke_billing,
  ]
}
