#!/usr/bin/env bash
# Deploy identity-svc, billing-svc, clinical-svc from a developer's machine,
# pinning the CORS_ALLOWED_ORIGINS env var on every revision.
#
# Why this script exists:
#   Cloud Build deploys (cloudbuild-webapp-backend.yaml) require the Cloud
#   Build SA to have roles/iam.serviceAccountUser on each runtime SA. Until
#   that's granted, deploys happen from developer credentials. This script
#   wraps the gcloud commands so CORS is always set — without it, every
#   ad-hoc `gcloud run deploy` reverts CORS to its source default (see
#   2026-05-28 signup outage).
#
# Usage:
#   ./scripts/deploy-webapp-backend.sh <git-sha>
# Example:
#   ./scripts/deploy-webapp-backend.sh $(git rev-parse --short HEAD)

set -euo pipefail

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <image-tag>" >&2
  echo "Hint:  $0 \$(git rev-parse --short HEAD)" >&2
  exit 1
fi

PROJECT="${PROJECT:-superwizor-ai-25ecd}"
REGION="${REGION:-europe-central2}"
REPO="europe-central2-docker.pkg.dev/${PROJECT}/services"

# The single source of truth for browser CORS origins. Mirror the
# substitution in cloudbuild-webapp-backend.yaml when changing this.
CORS_ORIGINS="${CORS_ORIGINS:-https://superwizor.ai,https://app.superwizor.ai,https://superwizor.web.app,https://superwizor-app.web.app,https://superwizor--*.web.app,https://superwizor-app--*.web.app,http://localhost:3000,http://localhost:8080}"

deploy_svc() {
  local svc="$1"
  local image="$2"
  echo ">>> Deploying ${svc} (image ${image})"
  # ^@^ tells gcloud to use @ as the dict-arg delimiter instead of ,
  # so CORS_ALLOWED_ORIGINS can carry its own commas (see
  # `gcloud topic escaping`). VERSION is added as a second entry.
  #
  # billing-svc also needs IDENTITY_SVC_URL so the Connect auth
  # interceptor can validate Firebase tokens via identity-svc — the
  # browser /admin AdminReset/AdminChange RPCs depend on this. Skip
  # the env for the other services so we don't ship a noisy override
  # they don't read.
  local env_set="^@^CORS_ALLOWED_ORIGINS=${CORS_ORIGINS}@VERSION=${TAG}"
  if [[ "$svc" == "billing-svc" ]]; then
    env_set="${env_set}@IDENTITY_SVC_URL=${IDENTITY_SVC_URL:-https://identity-svc-e3f32b232q-lm.a.run.app}"
  fi
  gcloud run deploy "${svc}" \
    --image="${image}" \
    --region="${REGION}" \
    --project="${PROJECT}" \
    --update-env-vars="${env_set}" \
    --quiet
}

deploy_svc identity-svc  "${REPO}/superwizor-identity:${TAG}"
deploy_svc billing-svc   "${REPO}/superwizor-billing:${TAG}"
deploy_svc clinical-svc  "${REPO}/superwizor-clinical:${TAG}"

echo ">>> All three services deployed at tag ${TAG} with CORS pinned"
