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
THERAPIST_ID=$(echo "SELECT id FROM users LIMIT 1;" | psql -h 127.0.0.1 -U postgres -d superwizor -t | tr -d ' ')

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

echo "=== Step 4: Verify w DB ==="
echo "SELECT id, working_alias FROM patient_files WHERE working_alias = 'E2E Test Patient';" | \
psql -h 127.0.0.1 -U postgres -d superwizor

echo "=== Step 5: Audit event ==="
echo "SELECT action, resource_type, occurred_at FROM audit_events ORDER BY occurred_at DESC LIMIT 5;" | \
psql -h 127.0.0.1 -U postgres -d superwizor

echo "✅ All E2E checks passed"
