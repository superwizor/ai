variable "project_id" {
  type        = string
  description = "The GCP project ID for staging"
  default     = "superwizor-ai-25ecd"
}

variable "project_number" {
  type        = string
  description = <<-EOT
    GCP project NUMBER (not project_id). Needed to construct the Pub/Sub
    service-agent principal `service-<NUMBER>@gcp-sa-pubsub.iam.gserviceaccount.com`,
    which is the identity that publishes to DLQ topics when a subscription
    crosses max_delivery_attempts. Without binding pubsub.publisher to this
    agent on each DLQ topic, dead-letter delivery silently fails.

    Lookup: `gcloud projects describe superwizor-ai-25ecd --format='value(projectNumber)'`.
  EOT
  default     = "344724821207"
}

variable "billing_svc_url" {
  type        = string
  description = <<-EOT
    Publicznie dostępny URL Cloud Run service `billing-svc` (HTTP port
    8081, dla admin crons + Stripe stub). Variable bo Cloud Run usługi
    są deployowane przez CI, nie terraform — pierwszy deploy wygeneruje
    URL którego wartość trzeba podać przez tfvars / env.

    Format: `https://billing-svc-<HASH>.<region>.run.app`.

    Lookup: `gcloud run services describe billing-svc --region=europe-central2 --format='value(status.url)'`.

    Empty value powoduje że Cloud Scheduler jobs są suspended (paused)
    przez handler w billing_crons.tf — fail-safe dla bootstrap środowiska.
  EOT
  default     = ""
}

variable "e2e_token_minters" {
  type        = list(string)
  description = <<-EOT
    Principals (e.g. `user:foo@example.com`, `serviceAccount:ci-runner@…`,
    `group:e2e-team@…`) that may impersonate the Firebase Admin SDK service
    account to mint custom tokens for end-to-end tests. Without this binding,
    `gcloud auth application-default login` users get
    `Permission 'iam.serviceAccounts.signBlob' denied` when the Firebase
    Admin SDK falls back to the IAM signBlob API.

    Keep this list small — granting `serviceAccountTokenCreator` here lets the
    member act as the Firebase Admin SA for any signing operation, including
    minting tokens for arbitrary end users.
  EOT
  default     = []
}

variable "stt_provider" {
  type = string
  # "deepgram" od 2026-07-17 (decyzja po walidacji e2e docs/39 Faza 2/3).
  # Default utrwalony tutaj, zeby zwykly terragrunt apply bez TF_VAR nie
  # cofnal providera na chirp. Rollback = zmiana tego defaulta.
  default = "deepgram"
}

variable "stt_provider_allowlist" {
  type    = string
  default = ""
}

variable "stt_order_gate" {
  type = string
  # "on" od 2026-07-17 (walidacja e2e docs/40: serialization held,
  # 4x ordering_gate_wait, zero bypass). Jak wyzej — default utrwalony.
  default = "on"
}

variable "stt_order_gate_max_wait_h" {
  type    = string
  default = "12"
}
