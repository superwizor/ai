---
name: ci-cd-and-deployments
description: Deploying backend services via GitHub Actions, Cloud Functions via Terragrunt, and the Next.js marketing site to Firebase Hosting.
---

# CI/CD and Deployments Skill

## 1. Staging Backend (Cloud Run)
* **Trigger:** Push to `main`.
* **Flow:** `.github/workflows/ci.yml` builds Docker images with commit SHA tags.
* **Migrations:** The `db-migrator` Cloud Run Job executes first to update schema before service deployment.

## 2. Cloud Functions (stt-worker, llm-worker)
* Not deployed via CI. Managed manually via Terragrunt:
  ```bash
  cd infra/environments/staging
  terragrunt apply -target=module.cloud_functions
  ```

## 3. Marketing Site (Next.js + Firebase)
* **Trigger:** Push to `main` modifying `marketing-site/` or triggering `marketing-site.yml`.
* **Keys:** Stripe Live publishable key (`pk_live_...`) and Firebase configs are compiled at build-time.
* **Flow:** Builds the static Next.js bundle and runs `firebase hosting:channel:deploy` (for PRs) or `firebase deploy` (for prod).
