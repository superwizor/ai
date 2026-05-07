variable "project_id" {
  type        = string
  description = "The GCP project ID for staging"
  default     = "superwizor-ai-25ecd"
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
