#!/usr/bin/env bash
# One-time IAM setup that lets the Cloud Build SA deploy revisions of
# identity-svc, billing-svc, and clinical-svc — so cloudbuild-webapp-backend.yaml
# can run end-to-end (build → push → deploy) without a developer running
# scripts/deploy-webapp-backend.sh by hand.
#
# Two roles are needed:
#   1. roles/run.developer at the project level (deploy revisions)
#   2. roles/iam.serviceAccountUser on each runtime SA (actAs the
#      service account that the Cloud Run revision will run as)
#
# Run this once per project. Re-running is idempotent.

set -euo pipefail

PROJECT="${PROJECT:-superwizor-ai-25ecd}"
PROJECT_NUMBER="$(gcloud projects describe "${PROJECT}" --format='value(projectNumber)')"
CB_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

echo ">>> Granting roles/run.developer to ${CB_SA} on project ${PROJECT}"
gcloud projects add-iam-policy-binding "${PROJECT}" \
  --member="serviceAccount:${CB_SA}" \
  --role="roles/run.developer" \
  --condition=None \
  --quiet >/dev/null

# Runtime SAs that the three Cloud Run services actAs.
RUNTIME_SAS=(
  "${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"        # identity-svc default compute SA
  "billing-svc@${PROJECT}.iam.gserviceaccount.com"
  "clinical-svc@${PROJECT}.iam.gserviceaccount.com"
)

for SA in "${RUNTIME_SAS[@]}"; do
  echo ">>> Granting roles/iam.serviceAccountUser on ${SA} to ${CB_SA}"
  gcloud iam service-accounts add-iam-policy-binding "${SA}" \
    --member="serviceAccount:${CB_SA}" \
    --role="roles/iam.serviceAccountUser" \
    --project="${PROJECT}" \
    --quiet >/dev/null
done

echo ">>> Done. Cloud Build can now deploy identity-svc / billing-svc / clinical-svc."
