---
name: google-play-deployer
description: Guides automated Android App Bundle (.aab) releases and uploads to Google Play Console using the Go deployment script, Google Play Developer API, and Service Account Impersonation.
---

# Google Play Deployer Skill

This skill guides building and publishing the Android app bundle (.aab) to Google Play Console from the command line, bypassing restrictions on service account key downloads.

## Architecture & Integration
*   **Script Path:** `superwizor-backend/scripts/upload_to_play.go`
*   **Terminal Command:** `./KOMENDY/10` (builds app bundle and runs the Go script)
*   **Service Account:** `google-play-deployer@superwizor-ai-25ecd.iam.gserviceaccount.com`

## Execution Steps

### 1. Verification of Local ADC Setup
The deployment script uses local Application Default Credentials (ADC) token impersonation. If authorization fails, the user must run:
```bash
gcloud auth application-default login --scopes=https://www.googleapis.com/auth/androidpublisher,https://www.googleapis.com/auth/cloud-platform
gcloud config set auth/impersonate_service_account google-play-deployer@superwizor-ai-25ecd.iam.gserviceaccount.com
```

### 2. Running Upload
To build and upload the app bundle to Google Play (Internal Testing track):
```bash
./KOMENDY/10
```
This runs the Go uploader by passing the active impersonated token with the correct scope:
```bash
go run scripts/upload_to_play.go -token $(gcloud auth application-default print-access-token --scopes=https://www.googleapis.com/auth/androidpublisher)
```

## Troubleshooting & Key Gotchas

*   **Error 403: Request had insufficient authentication scopes**
    *   *Cause:* The token was printed using gcloud's default scopes instead of the explicit `androidpublisher` scope.
    *   *Fix:* Run `gcloud auth application-default print-access-token` with `--scopes=https://www.googleapis.com/auth/androidpublisher`.

*   **Error 403: The caller does not have permission, forbidden**
    *   *Cause:* The GCP project is not linked, or the service account `google-play-deployer@...` is not invited to Google Play Console under **Users and permissions** (Użytkownicy i uprawnienia) with release/admin permissions for `ai.superwizor.superwizor`.
    *   *Fix:* Ensure the service account email is added as an active user in Play Console with the "Release manager" role for the app.

*   **Error 400: Media type 'application/zip' is not supported**
    *   *Cause:* The Go SDK automatically detects the mime-type of `.aab` (which is a zip package) as `application/zip`.
    *   *Fix:* The `Bundles.Upload` method must explicitly force the Content-Type using:
        `googleapi.ContentType("application/octet-stream")`
