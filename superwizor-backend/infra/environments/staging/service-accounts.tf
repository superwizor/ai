data "google_project" "this" {
  project_id = var.project_id
}

resource "google_service_account" "ingestion_svc" {
  account_id   = "ingestion-svc"
  display_name = "Ingestion Service SA"
  project      = var.project_id
}

# clinical-svc needs its own SA so it can:
#   - read the postgres-database-url secret (cloudsql.client + secretAccessor)
#   - decrypt the report_ciphertext / text_ciphertext columns written by
#     ai-pipeline-svc (cloudkms.cryptoKeyEncrypterDecrypter on app-data-key)
# Without these, GetSessionDetails silently returns an empty Reports list
# because cryptobox.Decrypt errors out and the handler swallows the error.
resource "google_service_account" "clinical_svc" {
  account_id   = "clinical-svc"
  display_name = "Clinical Service SA"
  project      = var.project_id
}

resource "google_service_account" "stt_worker" {
  account_id   = "stt-worker"
  display_name = "STT Worker SA"
  project      = var.project_id
}

# notification-svc needs:
#   - cloudsql.client (read fcm_tokens, write notification_deliveries)
#   - secretmanager.secretAccessor on postgres-database-url
#   - datastore.user (Firestore — the ONLY backend service allowed to write)
#   - firebasecloudmessaging.messagesSender (FCM push via Admin SDK)
#   - eventarc.eventReceiver (Pub/Sub-triggered Cloud Function workers)
# This SA is shared by both the Cloud Run server (cmd/server) and the
# Cloud Functions Gen2 workers (cmd/worker/*).
resource "google_service_account" "notification_svc" {
  account_id   = "notification-svc"
  display_name = "Notification Service SA"
  project      = var.project_id
}

resource "google_service_account" "llm_worker" {
  account_id   = "llm-worker"
  display_name = "LLM Worker SA"
  project      = var.project_id
}

# identity-svc needs its own SA so it can:
#   - read postgres-database-url secret (cloudsql.client + secretAccessor)
# It does NOT need KMS access because it never touches PHI columns
# (no transcripts / reports / patient files). Trial-signup writes
# usage_counters via billing-svc, not directly.
#
# Slice 1 of feat/web-app (docs/18 R6) — moves identity-svc off the
# default Compute SA. The CI deploy step must pass
# `--service-account=identity-svc@…` for this binding to take effect
# on Cloud Run.
resource "google_service_account" "identity_svc" {
  account_id   = "identity-svc"
  display_name = "Identity Service SA"
  project      = var.project_id
}

# identity-svc mints Firebase custom tokens for SSO (marketing-site →
# Flutter web app via signInWithCustomToken — the "Kartoteki" handoff).
# Under ADC on Cloud Run the Firebase Admin SDK signs the token with the
# runtime SA's OWN key via the IAM Credentials signBlob API, which requires
# the SA to be able to create tokens AS ITSELF. Without this grant,
# identity.MintAppLoginToken returns 500 and the SSO redirect falls back to
# the password login form (re-auth prompt). See
# services/identity-svc/internal/adapters/firebase/auth.go::CustomToken
# (the comment there says: "the SA itself needs serviceAccountTokenCreator
# on itself"). The dedicated identity-svc SA (Slice 1) replaced the default
# Compute SA, so this self-grant must be pinned here or it's missing.
resource "google_service_account_iam_member" "identity_svc_self_token_creator" {
  service_account_id = google_service_account.identity_svc.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:${google_service_account.identity_svc.email}"
}

resource "google_project_iam_member" "ingestion_signer" {
  project = var.project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

resource "google_storage_bucket_iam_member" "ingestion_storage" {
  # Zmienione na poprawne odwołanie do bucketu z używanego modułu "storage"
  bucket = module.storage.audio_uploads_bucket_name
  role   = "roles/storage.objectAdmin"
  member = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "ingestion_db_pwd" {
  project   = var.project_id
  secret_id = "postgres-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

resource "google_project_iam_member" "ingestion_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.ingestion_svc.email}"
}

# clinical-svc IAM
resource "google_project_iam_member" "clinical_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.clinical_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "clinical_db_pwd" {
  project   = var.project_id
  secret_id = "postgres-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.clinical_svc.email}"
}

resource "google_kms_crypto_key_iam_member" "clinical_kms" {
  crypto_key_id = module.kms.app_data_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.clinical_svc.email}"
}

# identity-svc IAM (least privilege — no KMS, no Firestore).
resource "google_project_iam_member" "identity_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.identity_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "identity_db_pwd" {
  project   = var.project_id
  secret_id = "postgres-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.identity_svc.email}"
}

# identity-svc needs Firebase Auth Admin to:
#   - check email verification status (GetUser → IsEmailVerified)
#   - generate email verification links (EmailVerificationLinkWithSettings)
# These are used by the custom Resend-backed verification flow
# (CreateUser + ResendVerificationEmail RPCs). Without this role the
# Firebase Admin SDK returns 400 INSUFFICIENT_PERMISSION and the
# verification email is silently dropped.
resource "google_project_iam_member" "identity_firebase_auth" {
  project = var.project_id
  role    = "roles/firebaseauth.admin"
  member  = "serviceAccount:${google_service_account.identity_svc.email}"
}

# notification-svc IAM
resource "google_project_iam_member" "notification_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.notification_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "notification_db_pwd" {
  project   = var.project_id
  secret_id = "postgres-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.notification_svc.email}"
}

# Firestore writer — this SA is the ONLY backend service allowed
# (architecture §6.3). Don't grant datastore.user to other services.
resource "google_project_iam_member" "notification_firestore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${google_service_account.notification_svc.email}"
}

# FCM via Firebase Admin SDK.
#
# We use `roles/firebasecloudmessaging.admin` because the narrower
# `roles/firebasecloudmessaging.messagesSender` role doesn't exist in
# this project's IAM catalog (it's a recent variant that hasn't
# propagated to all projects). Admin grants full read/write to the FCM
# API resources, which is broader than ideal — the worker only needs
# `cloudmessaging.messages.create` — but it's the smallest pre-defined
# role available right now.
#
# To narrow further, define a custom role with just
# `cloudmessaging.messages.create` and swap this line. The CIS
# security checklist (out of scope for Phase 3) calls this out.
resource "google_project_iam_member" "notification_fcm" {
  project = var.project_id
  role    = "roles/firebasecloudmessaging.admin"
  member  = "serviceAccount:${google_service_account.notification_svc.email}"
}

# Eventarc trigger receiver — Cloud Functions Gen2 notification workers
# (post docs/21 Faza-4: on-status + on-deleted; the three per-topic workers
# on-uploaded/-transcribed/-report were consolidated into on-status)
resource "google_project_iam_member" "notification_worker_eventarc" {
  project = var.project_id
  role    = "roles/eventarc.eventReceiver"
  member  = "serviceAccount:${google_service_account.notification_svc.email}"
}

# Pub/Sub service agent → SA token creator on notification-svc, so Eventarc
# can mint tokens as the worker SA when invoking the function (same pattern
# as stt_worker / llm_worker above).
resource "google_service_account_iam_member" "pubsub_sa_notification_token_creator" {
  service_account_id = google_service_account.notification_svc.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# S3: Allow the Pub/Sub service agent to create tokens for worker SAs so Eventarc
# can authenticate invocations with the correct service account identity.
resource "google_service_account_iam_member" "pubsub_sa_stt_token_creator" {
  service_account_id = google_service_account.stt_worker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

resource "google_service_account_iam_member" "pubsub_sa_llm_token_creator" {
  service_account_id = google_service_account.llm_worker.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = "serviceAccount:service-${data.google_project.this.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# ============================================================================
# billing-svc — Phase 3 (slice 1 stub gRPC server, slice 3 cron HTTP + outbox).
#
# Replaces the old default compute SA that the Phase 2 stub ran on.
# Internal-only Cloud Run; gRPC invoked by clinical-svc/ingestion-svc/
# ai-pipeline-svc, plus HTTP cron endpoints invoked by Cloud Scheduler.
# ============================================================================
resource "google_service_account" "billing_svc" {
  account_id   = "billing-svc"
  display_name = "billing-svc (Phase 3)"
  project      = var.project_id
}

resource "google_project_iam_member" "billing_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.billing_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "billing_db_pwd" {
  project   = var.project_id
  secret_id = "postgres-database-url"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.billing_svc.email}"
}

resource "google_secret_manager_secret_iam_member" "billing_stripe_secret" {
  project   = var.project_id
  secret_id = "stripe-webhook-secret"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.billing_svc.email}"
}


# KMS dla envelope encryption Stripe customer ID (ADR-BL-004).
# Slice 1 nie używa cryptobox, ale binding zostawiamy ready — slice 2 będzie
# bezpośrednio go używał.
resource "google_kms_crypto_key_iam_member" "billing_kms" {
  crypto_key_id = module.kms.app_data_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${google_service_account.billing_svc.email}"
}

# ============================================================================
# Cloud Scheduler dla billing crons (Phase 3, slice 3).
# Cloud Scheduler woła HTTP endpointy z OIDC tokenem podpisanym przez
# dedykowane SA cloud-scheduler-billing; Cloud Run frontend waliduje token,
# wpuszcza tylko jeśli SA ma roles/run.invoker.
# ============================================================================
resource "google_service_account" "cloud_scheduler_billing" {
  account_id   = "cloud-scheduler-billing"
  display_name = "Cloud Scheduler → billing-svc HTTP crons"
  project      = var.project_id
}

resource "google_cloud_run_v2_service_iam_member" "scheduler_invoke_billing" {
  project  = var.project_id
  location = "europe-central2"
  name     = "billing-svc"
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_scheduler_billing.email}"
}

# ============================================================================
# Cloud Run public-invocability for Flutter- and browser-facing services.
#
# These services are deployed by CI's `gcloud run deploy --allow-unauthenticated`
# (the service revisions themselves are not yet terraform-managed), but we
# pin the IAM policy here so manual `add-iam-policy-binding` / `remove-iam
# -policy-binding` commands and accidental --no-allow-unauthenticated deploys
# can't quietly break Flutter or the web /account/ page.
#
# Public at the Cloud Run frontend — the actual user identity is verified
# at the application layer via Firebase ID token (see identity-svc's
# Firebase Admin SDK call paths) and per-service Connect interceptors.
#
# CORS preflight (OPTIONS) requests from browsers are anonymous by spec
# (no Authorization header), so any service the marketing-site calls
# directly MUST be in this list — otherwise Google Frontend 403s the
# preflight and the browser reports a CORS error before the in-app
# CORS middleware can respond. The /account/ page's Subskrypcja card
# hits billing-svc.GetSubscription directly (see commit aff0e8e and
# docs/PROGRESS.md "Subskrypcja card calls billing-svc directly"),
# which is why billing-svc is in the public list.
#
# Internal-only services (ai-pipeline-svc, llm-worker, stt-worker) stay
# SA-bound — no browser ever calls them.
# ============================================================================
locals {
  public_cloud_run_services = [
    "identity-svc",
    "clinical-svc",
    "ingestion-svc",
    "api-service",
    "notification-svc", # Phase 3 — Flutter calls RegisterFCMToken etc.
    "billing-svc",      # marketing-site /account/ Subskrypcja card calls GetSubscription directly
  ]
}

resource "google_cloud_run_v2_service_iam_member" "public_invoker" {
  for_each = toset(local.public_cloud_run_services)

  project  = var.project_id
  location = "europe-central2"
  name     = each.key
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# ============================================================================
# E2E test prerequisite: grant explicit principals the right to call
# `signBlob` on the Firebase Admin SDK service account, which the Firebase
# Admin Go SDK invokes when it falls back from key-based signing to API-based
# signing (i.e., whenever credentials come from ADC rather than a JSON key).
#
# The Firebase Admin SDK SA `firebase-adminsdk-fbsvc@<project>` is auto-
# created by Firebase when the project is provisioned; we only attach IAM
# bindings here, we don't manage its lifecycle.
#
# Members live in `var.e2e_token_minters` (default: empty). Add via tfvars
# or override file rather than editing this list inline:
#
#   e2e_token_minters = [
#     "user:dev1@example.com",
#     "serviceAccount:e2e-runner@${PROJECT_ID}.iam.gserviceaccount.com",
#   ]
# ============================================================================
resource "google_service_account_iam_member" "e2e_firebase_token_creator" {
  for_each = toset(var.e2e_token_minters)

  service_account_id = "projects/${var.project_id}/serviceAccounts/firebase-adminsdk-fbsvc@${var.project_id}.iam.gserviceaccount.com"
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.key
}
