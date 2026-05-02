#!/bin/bash
set -euo pipefail

PROJECT_ID="superwizor-ai-25ecd"
REGION="europe-central2"

IDENTITY_URL=$(gcloud run services describe identity-svc \
  --region=${REGION} --project=${PROJECT_ID} \
  --format="value(status.url)")

TOKEN=$(gcloud auth print-identity-token)
UID_SUFFIX=$(date +%s)

grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d "{
    \"firebase_uid\": \"test_uid_${UID_SUFFIX}\",
    \"email\": \"test_${UID_SUFFIX}@example.com\",
    \"role\": \"USER_ROLE_THERAPIST\",
    \"first_name\": \"E2E\",
    \"last_name\": \"Test\",
    \"ui_language\": \"pl\",
    \"timezone\": \"Europe/Warsaw\",
    \"has_accepted_tos\": true
  }" \
  ${IDENTITY_URL#https://}:443 \
  identity.v1.IdentityService/CreateUser
