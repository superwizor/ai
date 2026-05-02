#!/bin/bash
set -euo pipefail

# Prerequisites:
# - User created w Firebase Auth
# - User row exists w PostgreSQL (CreateUser called)

PROJECT_ID="superwizor-ai-25ecd"
REGION="europe-central2"

# Get service URLs
IDENTITY_URL=$(gcloud run services describe identity-svc \
  --region=${REGION} --project=${PROJECT_ID} \
  --format="value(status.url)")

CLINICAL_URL=$(gcloud run services describe clinical-svc \
  --region=${REGION} --project=${PROJECT_ID} \
  --format="value(status.url)")

# Get fresh ID token (Cloud Run service-to-service)
TOKEN=$(gcloud auth print-identity-token)

echo "=== Step 1: Health checks ==="
grpcurl -H "authorization: Bearer ${TOKEN}" \
  ${IDENTITY_URL#https://}:443 \
  identity.v1.IdentityService/HealthCheck

grpcurl -H "authorization: Bearer ${TOKEN}" \
  ${CLINICAL_URL#https://}:443 \
  clinical.v1.ClinicalService/HealthCheck

echo "=== Step 2: List modalities ==="
grpcurl -H "authorization: Bearer ${TOKEN}" \
  ${CLINICAL_URL#https://}:443 \
  clinical.v1.ClinicalService/ListModalities

echo "=== Step 3: Create patient file ==="
UID_SUFFIX=$(date +%s)
THERAPIST_ID=$(grpcurl -H "authorization: Bearer ${TOKEN}" \
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
  identity.v1.IdentityService/CreateUser | grep '"id":' | cut -d'"' -f4)


grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d "{
    \"therapist_id\": \"${THERAPIST_ID}\",
    \"modality_code\": \"CBT\",
    \"working_alias\": \"E2E Test Patient\",
    \"process_type\": \"PROCESS_TYPE_INDIVIDUAL\",
    \"initial_complaint\": \"E2E test\",
    \"has_recording_consent\": true
  }" \
  ${CLINICAL_URL#https://}:443 \
  clinical.v1.ClinicalService/CreatePatientFile

echo "=== Step 4: Verify via ListPatientFiles ==="
grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d "{
    \"therapist_id\": \"${THERAPIST_ID}\",
    \"page_size\": 5
  }" \
  ${CLINICAL_URL#https://}:443 \
  clinical.v1.ClinicalService/ListPatientFiles

echo "✅ All E2E checks passed"
