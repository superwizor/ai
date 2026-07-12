# Workspace Rules

The following are absolute architectural guardrails that apply to the Superwizor AI project. These must be followed by every AI Agent writing code in this repository.

## Rule 1: Strict No-PHI Analytics Policy
* **Constraint:** Never log or send Patient Health Information (PHI) or personal details (such as transcripts, session summaries, patient names, or therapist comments) to analytics pipelines (e.g., Firebase Analytics) or system logs (`log.Printf`).
* **Implementation:** All telemetry parameters must pass through the client-side `ParamSanitizer` to enforce a strict allowlist.

## Rule 2: Safe Go Database Transactions Rollback
* **Constraint:** To avoid database connection leaks, every transaction block must call a deferred rollback checking for errors.
* **Implementation:**
  ```go
  tx, err := db.BeginTx(ctx, nil)
  if err != nil { ... }
  defer func() { _ = tx.Rollback(ctx) }()
  ```
  *Note: Bare `defer tx.Rollback()` is banned by the linter. Always wrap in an anonymous function with an errcheck block `_ =` to handle return values safely.*

## Rule 3: Impersonation Policy (Zero Trust)
* **Constraint:** Downloading service account JSON keys is strictly blocked by GCP organizational policies (`constraints/iam.disableServiceAccountKeyCreation`).
* **Implementation:** Always use Workload Identity Federation (WIF) in GitHub Actions CI/CD workflows. For local developer terminal CLI authentication, use `gcloud auth application-default login` with `gcloud config set auth/impersonate_service_account`. Never attempt to download or generate physical JSON keys.
