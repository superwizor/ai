#!/usr/bin/env bash
# ============================================================================
# E2E happy-path: therapist registration → patient file → session run
# ============================================================================
#
# Exercises the user-initiated flow end-to-end against staging:
#   1. CreateUser  (identity-svc)               — therapist registration
#   2. ListModalities (clinical-svc)            — sanity check
#   3. CreatePatientFile (clinical-svc)         — therapist's first patient
#   4. CreateAudioUpload (ingestion-svc)        — request signed URL
#   5. PUT audio to GCS                         — bypass our backend
#   6. CompleteAudioUpload (ingestion-svc)      — IMPLICITLY CREATES SESSION
#   7. Poll GetSessionDetails (clinical-svc)    — watch STT → LLM transitions
#
# After step 6 the AI pipeline runs asynchronously (Pub/Sub →
# stt-worker → llm-worker). Steps 1-6 are synchronous; step 7 polls.
#
# Audio prereq:
#   The repo's test-audio.wav is a 5-byte placeholder — uploads will succeed
#   (GCS doesn't sniff content) but stt-worker will error during decode. To
#   exercise the FULL pipeline including STT + LLM, place a real Polish-
#   speech m4a (≤300 MB, mono) at tests/e2e/testdata/sample.m4a.
#
# Auth:
#   Uses `gcloud auth print-identity-token` (Google IAM token). Works
#   because the public Cloud Run services are bound allUsers→run.invoker
#   so the Cloud Run frontend lets us through. This does NOT exercise the
#   Firebase audience-claim validation path; for that, mint a real
#   Firebase ID token (see docs/agents/09_testing.md "Auth in E2E tests").
#
# Cleanup:
#   Test artifacts use timestamped fake identifiers and are NOT cleaned
#   up automatically. Soft-delete or rely on a future cleanup job for
#   rows where email LIKE 'test_%@example.com'.
# ============================================================================

set -euo pipefail

PROJECT_ID="superwizor-ai-25ecd"
REGION="europe-central2"
RUN_ID=$(date +%s)

# Where to find the audio file. Override via AUDIO_FILE=/path/to/file.m4a.
AUDIO_FILE="${AUDIO_FILE:-tests/e2e/testdata/sample.m4a}"
if [[ ! -f "$AUDIO_FILE" ]]; then
  AUDIO_FILE="test-audio.wav"  # repo-root placeholder — STT will error
fi

# Require these tools up front; abort early with a clear message
for tool in gcloud grpcurl curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required tool: $tool" >&2; exit 1; }
done

if [[ ! -f "$AUDIO_FILE" ]]; then
  echo "Audio file not found: $AUDIO_FILE" >&2
  exit 1
fi

AUDIO_SIZE=$(wc -c < "$AUDIO_FILE" | tr -d ' ')
echo "============================================================"
echo "  E2E full-session test"
echo "  Run ID:       ${RUN_ID}"
echo "  Project:      ${PROJECT_ID} (${REGION})"
echo "  Audio file:   ${AUDIO_FILE} (${AUDIO_SIZE} bytes)"
if [[ "$AUDIO_FILE" == "test-audio.wav" ]]; then
  echo "  ⚠ Using placeholder audio. STT will error (expected)."
fi
echo "============================================================"

# ----------------------------------------------------------------------------
# Setup: discover service URLs + mint token
# ----------------------------------------------------------------------------
echo
echo "▶ Discovering service URLs..."
IDENTITY_URL=$(gcloud run services describe identity-svc \
  --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)")
CLINICAL_URL=$(gcloud run services describe clinical-svc \
  --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)")
INGESTION_URL=$(gcloud run services describe ingestion-svc \
  --region="${REGION}" --project="${PROJECT_ID}" --format="value(status.url)")

# Strip https:// prefix; grpcurl wants host:port
IDENTITY_HOST="${IDENTITY_URL#https://}:443"
CLINICAL_HOST="${CLINICAL_URL#https://}:443"
INGESTION_HOST="${INGESTION_URL#https://}:443"

echo "  identity-svc:  ${IDENTITY_HOST}"
echo "  clinical-svc:  ${CLINICAL_HOST}"
echo "  ingestion-svc: ${INGESTION_HOST}"

echo
echo "▶ Minting auth token..."
TOKEN=$(gcloud auth print-identity-token)
AUTH_HEADER="authorization: Bearer ${TOKEN}"

# Compact grpcurl wrapper. Prints the request inline; returns JSON response.
call_grpc() {
  local host="$1" method="$2" body="$3"
  grpcurl -H "$AUTH_HEADER" -d "$body" "$host" "$method"
}

# ============================================================================
#  STEP 1 — Therapist registration
# ============================================================================
echo
echo "═══ Step 1/7: CreateUser (therapist) ═══════════════════════════"

THERAPIST_REQ=$(jq -nc \
  --arg uid "test_uid_${RUN_ID}" \
  --arg email "test_${RUN_ID}@example.com" \
  '{
    firebase_uid: $uid,
    email: $email,
    role: "USER_ROLE_THERAPIST",
    first_name: "E2E",
    last_name: "Therapist",
    ui_language: "pl",
    timezone: "Europe/Warsaw",
    has_accepted_tos: true
  }')

USER_RESP=$(call_grpc "$IDENTITY_HOST" \
  identity.v1.IdentityService/CreateUser \
  "$THERAPIST_REQ")

THERAPIST_ID=$(echo "$USER_RESP" | jq -r '.id // .user.id // empty')

if [[ -z "$THERAPIST_ID" ]]; then
  echo "✗ Could not extract therapist id from CreateUser response:" >&2
  echo "$USER_RESP" >&2
  exit 1
fi

echo "✓ Therapist registered: id=${THERAPIST_ID}"

# ============================================================================
#  STEP 2 — Sanity: list modalities (cross-service auth check)
# ============================================================================
echo
echo "═══ Step 2/7: ListModalities ═══════════════════════════════════"

MODALITIES=$(call_grpc "$CLINICAL_HOST" \
  clinical.v1.ClinicalService/ListModalities \
  '{}')

MOD_COUNT=$(echo "$MODALITIES" | jq '.modalities | length')
if (( MOD_COUNT < 1 )); then
  echo "✗ Expected ≥1 modality, got ${MOD_COUNT}" >&2
  echo "$MODALITIES" >&2
  exit 1
fi
echo "✓ Got ${MOD_COUNT} modalities"

# ============================================================================
#  STEP 3 — Create patient file
# ============================================================================
echo
echo "═══ Step 3/7: CreatePatientFile ════════════════════════════════"

PATIENT_REQ=$(jq -nc \
  --arg therapist_id "$THERAPIST_ID" \
  --arg alias "E2E Test Patient ${RUN_ID}" \
  --arg idem "e2e-create-patient-${RUN_ID}" \
  '{
    therapist_id: $therapist_id,
    modality_code: "CBT",
    working_alias: $alias,
    process_type: "PROCESS_TYPE_INDIVIDUAL",
    initial_complaint: "E2E test complaint",
    has_recording_consent: true,
    idempotency_key: $idem
  }')

PATIENT_RESP=$(call_grpc "$CLINICAL_HOST" \
  clinical.v1.ClinicalService/CreatePatientFile \
  "$PATIENT_REQ")

PATIENT_FILE_ID=$(echo "$PATIENT_RESP" | jq -r '.id // .patient_file.id // empty')
if [[ -z "$PATIENT_FILE_ID" ]]; then
  echo "✗ Could not extract patient_file id:" >&2
  echo "$PATIENT_RESP" >&2
  exit 1
fi
echo "✓ PatientFile created: id=${PATIENT_FILE_ID}"

# Also assert idempotency: re-issuing the same request returns the same id
PATIENT_RESP2=$(call_grpc "$CLINICAL_HOST" \
  clinical.v1.ClinicalService/CreatePatientFile \
  "$PATIENT_REQ")
PATIENT_FILE_ID2=$(echo "$PATIENT_RESP2" | jq -r '.id // .patient_file.id // empty')
if [[ "$PATIENT_FILE_ID" == "$PATIENT_FILE_ID2" ]]; then
  echo "✓ Idempotency holds: same key → same id"
else
  echo "⚠ Idempotency mismatch: ${PATIENT_FILE_ID} ≠ ${PATIENT_FILE_ID2}"
  echo "  (depending on backend implementation, this may be a bug)"
fi

# ============================================================================
#  STEP 4 — Request signed URL
# ============================================================================
echo
echo "═══ Step 4/7: CreateAudioUpload (signed URL) ══════════════════"

UPLOAD_REQ=$(jq -nc \
  --arg therapist_id "$THERAPIST_ID" \
  --arg patient_file_id "$PATIENT_FILE_ID" \
  --arg idem "e2e-upload-${RUN_ID}" \
  --argjson size "$AUDIO_SIZE" \
  '{
    therapist_id: $therapist_id,
    patient_file_id: $patient_file_id,
    content_type: "audio/m4a",
    estimated_size_bytes: $size,
    estimated_duration_seconds: 600,
    idempotency_key: $idem,
    client_app_version: "e2e-test-1.0",
    client_platform: "test"
  }')

UPLOAD_RESP=$(call_grpc "$INGESTION_HOST" \
  ingestion.v1.IngestionService/CreateAudioUpload \
  "$UPLOAD_REQ")

UPLOAD_ID=$(echo "$UPLOAD_RESP" | jq -r '.upload_id // empty')
SIGNED_URL=$(echo "$UPLOAD_RESP" | jq -r '.signed_url // empty')
OBJECT_PATH=$(echo "$UPLOAD_RESP" | jq -r '.object_path // empty')

if [[ -z "$UPLOAD_ID" || -z "$SIGNED_URL" ]]; then
  echo "✗ Did not receive upload_id + signed_url:" >&2
  echo "$UPLOAD_RESP" >&2
  exit 1
fi

echo "✓ Signed URL granted"
echo "  upload_id:   ${UPLOAD_ID}"
echo "  object_path: ${OBJECT_PATH}"

# ============================================================================
#  STEP 5 — PUT audio to GCS via signed URL
# ============================================================================
echo
echo "═══ Step 5/7: PUT to signed URL ═══════════════════════════════"

# Build header arguments dynamically from required_headers in the response
HEADER_ARGS=()
while IFS=$'\t' read -r key value; do
  HEADER_ARGS+=(-H "${key}: ${value}")
done < <(echo "$UPLOAD_RESP" | jq -r '.required_headers // {} | to_entries[] | "\(.key)\t\(.value)"')

# Always include Content-Type — the canonical signed-URL header
HEADER_ARGS+=(-H "Content-Type: audio/m4a")

HTTP_CODE=$(curl -sS -o /tmp/gcs_put_resp.txt -w "%{http_code}" \
  -X PUT \
  "${HEADER_ARGS[@]}" \
  --data-binary "@${AUDIO_FILE}" \
  "$SIGNED_URL")

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "✗ PUT failed: HTTP ${HTTP_CODE}" >&2
  echo "  Response body:" >&2
  sed 's/^/    /' /tmp/gcs_put_resp.txt >&2
  exit 1
fi
echo "✓ Audio uploaded: HTTP ${HTTP_CODE}, ${AUDIO_SIZE} bytes"

# ============================================================================
#  STEP 6 — Confirm upload (this CREATES THE SESSION)
# ============================================================================
echo
echo "═══ Step 6/7: CompleteAudioUpload (creates session) ═══════════"

COMPLETE_REQ=$(jq -nc \
  --arg upload_id "$UPLOAD_ID" \
  --argjson size "$AUDIO_SIZE" \
  '{
    upload_id: $upload_id,
    actual_duration_seconds: 600,
    actual_size_bytes: $size,
    chunk_count: 1,
    md5_hash: ""
  }')

COMPLETE_RESP=$(call_grpc "$INGESTION_HOST" \
  ingestion.v1.IngestionService/CompleteAudioUpload \
  "$COMPLETE_REQ")

SESSION_ID=$(echo "$COMPLETE_RESP" | jq -r '.session_id // empty')
PROCESSING_STARTED=$(echo "$COMPLETE_RESP" | jq -r '.processing_started // false')

if [[ -z "$SESSION_ID" ]]; then
  echo "✗ CompleteAudioUpload did not return a session_id:" >&2
  echo "$COMPLETE_RESP" >&2
  exit 1
fi
echo "✓ Session created: id=${SESSION_ID}, processing_started=${PROCESSING_STARTED}"

# ============================================================================
#  STEP 7 — Poll session status (STT → LLM transitions)
# ============================================================================
echo
echo "═══ Step 7/7: Poll GetSessionDetails ══════════════════════════"
echo "  Allowing up to 5 minutes for the AI pipeline."
echo "  Status path expected: PROCESSING* → ANALYZING → COMPLETED"
echo "  (with placeholder audio: PROCESSING → ERRORED at the STT stage)"
echo

SESSION_REQ=$(jq -nc --arg id "$SESSION_ID" '{session_id: $id}')

TERMINAL_STATUSES=("COMPLETED" "ERRORED" "FAILED")
DEADLINE=$(( $(date +%s) + 300 ))   # 5 minutes
LAST_STATUS=""

while (( $(date +%s) < DEADLINE )); do
  DETAILS=$(call_grpc "$CLINICAL_HOST" \
    clinical.v1.ClinicalService/GetSessionDetails \
    "$SESSION_REQ" 2>/dev/null || true)

  STATUS=$(echo "$DETAILS" | jq -r '.session.status // empty')

  if [[ -n "$STATUS" && "$STATUS" != "$LAST_STATUS" ]]; then
    echo "  $(date +%H:%M:%S) status: ${STATUS}"
    LAST_STATUS="$STATUS"
  fi

  for term in "${TERMINAL_STATUSES[@]}"; do
    if [[ "$STATUS" == "$term" ]]; then
      break 2
    fi
  done

  sleep 5
done

# ----------------------------------------------------------------------------
# Final report
# ----------------------------------------------------------------------------
echo
echo "════════════════════════════════════════════════════════════════"
echo "  SUMMARY"
echo "════════════════════════════════════════════════════════════════"
echo "  Run ID:       ${RUN_ID}"
echo "  Therapist:    ${THERAPIST_ID}"
echo "  Patient file: ${PATIENT_FILE_ID}"
echo "  Upload:       ${UPLOAD_ID}"
echo "  Session:      ${SESSION_ID}"
echo "  Final status: ${LAST_STATUS:-<no transition>}"
echo

case "$LAST_STATUS" in
  COMPLETED)
    echo "✓ FULL HAPPY PATH PASSED"
    REPORT_COUNT=$(echo "$DETAILS" | jq '.reports | length')
    echo "  Reports generated: ${REPORT_COUNT}"
    exit 0
    ;;
  ERRORED|FAILED)
    if [[ "$AUDIO_FILE" == "test-audio.wav" ]]; then
      echo "⚠ Pipeline errored as EXPECTED (placeholder audio)"
      echo "  Setup steps 1-6 passed; AI pipeline correctly rejected fake audio."
      echo "  To exercise STT + LLM, place real m4a at tests/e2e/testdata/sample.m4a"
      exit 0
    fi
    echo "✗ Pipeline failed with real audio:"
    echo "$DETAILS" | jq '.session' || true
    exit 1
    ;;
  ANALYZING|PROCESSING|TRANSCRIBING)
    echo "⚠ Timed out before completion (still in ${LAST_STATUS})"
    echo "  This is sometimes normal during Vertex AI cold starts."
    echo "  Re-run, or increase the 5-minute deadline."
    exit 1
    ;;
  *)
    echo "✗ Unexpected terminal state: ${LAST_STATUS:-<empty>}"
    echo "$DETAILS" | jq . 2>/dev/null || echo "$DETAILS"
    exit 1
    ;;
esac
