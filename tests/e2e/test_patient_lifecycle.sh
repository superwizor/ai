#!/bin/bash
set -euo pipefail

# E2E: Patient Lifecycle Status (migration 000058)
#
# Tests the full round-trip: set lifecycle via UpdatePatientFile gRPC call,
# verify it persists, and shows in ListPatientFiles. Runs against staging.
#
# Prerequisites:
# - cloud-sql-proxy running on 127.0.0.1:5432
# - gcloud auth configured
# - At least one patient_file exists in the test therapist's kartoteka

PROJECT_ID="superwizor-ai-25ecd"
REGION="europe-central2"

# Get service URL
CLINICAL_URL=$(gcloud run services describe clinical-svc \
  --region=${REGION} --project=${PROJECT_ID} \
  --format="value(status.url)")

# Get fresh ID token
TOKEN=$(gcloud auth print-identity-token)

echo "=== Step 1: Pick a test patient file ==="
PF_ID=$(echo "SELECT id FROM patient_files WHERE deleted_at IS NULL ORDER BY created_at DESC LIMIT 1;" | \
  psql -h 127.0.0.1 -U superwizor_app -d superwizor -t 2>/dev/null | tr -d ' ')

if [ -z "${PF_ID}" ]; then
  echo "❌ No patient file found in DB. Create one first."
  exit 1
fi
echo "Using patient_file_id: ${PF_ID}"

echo ""
echo "=== Step 2: Read current lifecycle ==="
CURRENT=$(echo "SELECT lifecycle_status FROM patient_files WHERE id = '${PF_ID}';" | \
  psql -h 127.0.0.1 -U superwizor_app -d superwizor -t | tr -d ' ')
echo "Current lifecycle_status: ${CURRENT}"

echo ""
echo "=== Step 3: Set lifecycle to PAUSED via gRPC ==="
grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d "{
    \"patient_file_id\": \"${PF_ID}\",
    \"lifecycle_status\": \"PAUSED\"
  }" \
  ${CLINICAL_URL#https://}:443 \
  clinical.v1.ClinicalService/UpdatePatientFile | tee /tmp/e2e_lifecycle_resp1.json

echo ""
echo "--- Verify response contains lifecycle_status = PAUSED ---"
RESP_STATUS=$(jq -r '.lifecycleStatus' /tmp/e2e_lifecycle_resp1.json)
if [ "${RESP_STATUS}" != "PAUSED" ]; then
  echo "❌ Expected lifecycleStatus=PAUSED in response, got: ${RESP_STATUS}"
  exit 1
fi
echo "✅ gRPC response: lifecycle_status=PAUSED"

echo ""
echo "=== Step 4: Verify DB state ==="
DB_STATUS=$(echo "SELECT lifecycle_status FROM patient_files WHERE id = '${PF_ID}';" | \
  psql -h 127.0.0.1 -U superwizor_app -d superwizor -t | tr -d ' ')
if [ "${DB_STATUS}" != "PAUSED" ]; then
  echo "❌ DB lifecycle_status expected PAUSED, got: ${DB_STATUS}"
  exit 1
fi
echo "✅ DB: lifecycle_status=PAUSED"

DB_CLOSED=$(echo "SELECT is_process_closed FROM patient_files WHERE id = '${PF_ID}';" | \
  psql -h 127.0.0.1 -U superwizor_app -d superwizor -t | tr -d ' ')
if [ "${DB_CLOSED}" != "f" ]; then
  echo "❌ PAUSED should have is_process_closed=false, got: ${DB_CLOSED}"
  exit 1
fi
echo "✅ DB: is_process_closed=false (PAUSED)"

echo ""
echo "=== Step 5: Set lifecycle to COMPLETED ==="
grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d "{
    \"patient_file_id\": \"${PF_ID}\",
    \"lifecycle_status\": \"COMPLETED\"
  }" \
  ${CLINICAL_URL#https://}:443 \
  clinical.v1.ClinicalService/UpdatePatientFile | tee /tmp/e2e_lifecycle_resp2.json

RESP_STATUS2=$(jq -r '.lifecycleStatus' /tmp/e2e_lifecycle_resp2.json)
if [ "${RESP_STATUS2}" != "COMPLETED" ]; then
  echo "❌ Expected lifecycleStatus=COMPLETED in response, got: ${RESP_STATUS2}"
  exit 1
fi
echo "✅ gRPC response: lifecycle_status=COMPLETED"

DB_STATUS2=$(echo "SELECT lifecycle_status FROM patient_files WHERE id = '${PF_ID}';" | \
  psql -h 127.0.0.1 -U superwizor_app -d superwizor -t | tr -d ' ')
if [ "${DB_STATUS2}" != "COMPLETED" ]; then
  echo "❌ DB lifecycle_status expected COMPLETED, got: ${DB_STATUS2}"
  exit 1
fi
echo "✅ DB: lifecycle_status=COMPLETED"

DB_CLOSED2=$(echo "SELECT is_process_closed FROM patient_files WHERE id = '${PF_ID}';" | \
  psql -h 127.0.0.1 -U superwizor_app -d superwizor -t | tr -d ' ')
if [ "${DB_CLOSED2}" != "t" ]; then
  echo "❌ COMPLETED should have is_process_closed=true, got: ${DB_CLOSED2}"
  exit 1
fi
echo "✅ DB: is_process_closed=true (COMPLETED)"

echo ""
echo "=== Step 6: Restore to ACTIVE ==="
grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d "{
    \"patient_file_id\": \"${PF_ID}\",
    \"lifecycle_status\": \"ACTIVE\"
  }" \
  ${CLINICAL_URL#https://}:443 \
  clinical.v1.ClinicalService/UpdatePatientFile | tee /tmp/e2e_lifecycle_resp3.json

RESP_STATUS3=$(jq -r '.lifecycleStatus' /tmp/e2e_lifecycle_resp3.json)
if [ "${RESP_STATUS3}" != "ACTIVE" ]; then
  echo "❌ Expected lifecycleStatus=ACTIVE in response, got: ${RESP_STATUS3}"
  exit 1
fi
echo "✅ gRPC response: lifecycle_status=ACTIVE"

echo ""
echo "=== Step 7: Verify lifecycle appears in ListPatientFiles ==="
grpcurl -H "authorization: Bearer ${TOKEN}" \
  -d "{\"therapist_id\": \"\", \"page_size\": 10}" \
  ${CLINICAL_URL#https://}:443 \
  clinical.v1.ClinicalService/ListPatientFiles | tee /tmp/e2e_lifecycle_list.json

# Check that our file appears with ACTIVE status
HAS_LIFECYCLE=$(jq -r ".patientFiles[] | select(.id == \"${PF_ID}\") | .lifecycleStatus" /tmp/e2e_lifecycle_list.json)
if [ "${HAS_LIFECYCLE}" != "ACTIVE" ]; then
  echo "❌ ListPatientFiles should show lifecycle_status=ACTIVE for ${PF_ID}, got: ${HAS_LIFECYCLE}"
  exit 1
fi
echo "✅ ListPatientFiles: lifecycle_status=ACTIVE appears in response"

echo ""
echo "=== Step 8: Cleanup — verify final DB state ==="
echo "SELECT id, lifecycle_status, is_process_closed FROM patient_files WHERE id = '${PF_ID}';" | \
  psql -h 127.0.0.1 -U superwizor_app -d superwizor

echo ""
echo "✅ All patient lifecycle E2E checks passed"
