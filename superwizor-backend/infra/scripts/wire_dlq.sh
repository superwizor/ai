#!/usr/bin/env bash
#
# wire_dlq.sh — patch Eventarc-managed Pub/Sub subscriptions with a
# dead-letter policy + max_delivery_attempts.
#
# WHY THIS EXISTS
# ---------------
# Cloud Functions Gen2's `event_trigger { ... }` block creates the
# Eventarc trigger and its underlying Pub/Sub subscription, but the
# google / google-beta terraform providers (verified up to v6.x)
# don't expose a `dead_letter_config` field on that block. The
# Eventarc-managed subscription is therefore created without DLQ; the
# only way to add one is to patch the subscription post-create via
# `gcloud pubsub subscriptions update`.
#
# This script is the patch step. Run it AFTER `terragrunt apply` (or
# any change that recreates a Cloud Function trigger). It's
# idempotent — re-running with the same values is a no-op against
# gcloud. CI runs it as the final step of the staging deploy
# workflow; operators run it manually after ad-hoc deploys (like the
# manual `gcloud functions deploy` path used during incident
# recovery).
#
# Symptom this script fixes:
#   Without DLQ, poison messages retry for the full 24h Pub/Sub
#   retention window. Documented incident: session b6c7a606 on
#   2026-05-14, ~100 retry attempts over 24+ hours before manual
#   `subscriptions seek --time=NOW` drained the queue. With DLQ
#   wired, the same message would dead-letter after 5 attempts
#   (~5-10 minutes) and operators would be paged via the alerting
#   policy on DLQ ingress.
#
# ORDERING GATE DEPENDS ON THESE VALUES (docs/40)
# ------------------------------------------------
# stt-worker's per-patient-file ordering gate uses INTENTIONAL NACKs
# against the audio.uploaded Eventarc subscription as its wait loop:
# a session whose predecessor is still processing is redelivered until
# the predecessor finishes. The gate's bypass window
# (STT_ORDER_GATE_MAX_WAIT_H, default 12h) is sized to stay BELOW the
# retry envelope configured here (~15-16h at 100 attempts x <=600s).
# If you lower max-delivery-attempts or shorten the backoff on the
# audio.uploaded trigger subscription, re-derive that envelope and
# shrink the gate's bypass window FIRST — otherwise waiting sessions
# will dead-letter and the DLQ reaper will FAIL healthy sessions.
#
# Provider-limitation tracking:
#   - docs/agents/TODO.md "Wire DLQ on Eventarc-managed Pub/Sub
#     subscriptions" — original issue spec.
#   - When the terraform provider catches up and exposes
#     `dead_letter_config` on `cloudfunctions2_function.event_trigger`,
#     delete this script and inline the config into the trigger block.
#
# USAGE
# -----
#   # default project: superwizor-ai-25ecd (staging)
#   ./infra/scripts/wire_dlq.sh
#
#   # override project for a different env
#   PROJECT=my-other-project ./infra/scripts/wire_dlq.sh
#
# Auth: ADC or a service account with at minimum:
#   - roles/eventarc.viewer  (read trigger → subscription mapping)
#   - roles/pubsub.editor    (update subscription dead_letter_policy)

set -euo pipefail

PROJECT="${PROJECT:-superwizor-ai-25ecd}"
REGION="${REGION:-europe-central2}"

# (function_name, dlq_topic, max_delivery_attempts) per worker. Keep
# this table in sync with infra/modules/cloud-functions/main.tf
# (search for `event_trigger { ... }`) and infra/modules/pubsub/main.tf
# (DLQ topic resources).
#
# Retry profile (applied to every subscription below — see RETRY_*):
#   minimum_backoff = 10s  (Pub/Sub floor — closest to "immediate"
#                          for transient LLM/Chirp errors)
#   maximum_backoff = 600s (Pub/Sub hard cap; 10-min ceiling)
#   With exponential growth (10s → 20s → 40s → 80s → ... → 600s
#   capped at attempt 7), the cumulative time covers ~16h before the
#   100-attempt budget runs out:
#     attempt  1   → first delivery
#     attempts 2-7 → ~20.5 min cumulative (transient burst window,
#                    each waiting 10-160s)
#     attempts 8-100 → 600s each, fills ~15.5 h
#     attempt  100 → message dead-letters
#   Doesn't quite hit 24h (Pub/Sub's max-retry-delay is hard-capped
#   at 600s) but the practical effect is the same: transient Chirp
#   `INTERNAL` / Vertex 503 errors self-heal within ~20 min, and
#   poison messages exit to the DLQ rather than riding retention.
#   This keeps transient Chirp `INTERNAL` / Vertex 503 errors
#   self-healing within minutes, while bounded poison messages
#   eventually exit to the DLQ instead of the 24h Pub/Sub retention
#   tail.
RETRY_MIN_BACKOFF="10s"
RETRY_MAX_BACKOFF="600s"

# max_delivery_attempts per worker. Same envelope (~24h) across the
# board; minor variation justified inline:
#   - stt-worker / llm-worker: 100 (deep retry budget; expensive
#     calls but transient failures during peak hours are common
#     enough to warrant the full envelope).
#   - notification-worker-*: 100 (FCM is mostly bursty-transient;
#     same envelope keeps the runbook simple — one number).
TRIGGERS=(
  "stt-worker:audio.uploaded.dlq:100"
  "llm-worker:transcript.completed.dlq:100"
  "notification-worker-on-deleted:session.deleted.dlq:100"
  "notification-worker-on-status:session.status_changed.dlq:100"
)

echo "Project: $PROJECT  Region: $REGION"
echo

for entry in "${TRIGGERS[@]}"; do
  IFS=':' read -r function_name dlq_topic max_attempts <<< "$entry"

  # Cloud Functions Gen2 + Eventarc: the trigger gets an auto-generated
  # name like `<function-name>-<6digit-suffix>`, NOT the function name
  # itself. We look up the *function*'s eventTrigger.trigger field —
  # a full resource path `projects/.../triggers/<actual-name>` — then
  # describe THAT trigger to get the subscription. Two indirections
  # (function → trigger resource path → subscription path) but each
  # step is deterministic and idempotent.
  trigger_path=$(gcloud functions describe "$function_name" \
    --gen2 \
    --region="$REGION" \
    --project="$PROJECT" \
    --format='value(eventTrigger.trigger)' 2>/dev/null || echo "")

  if [[ -z "$trigger_path" ]]; then
    echo "⚠ $function_name: Cloud Function not deployed (no eventTrigger). Skipping."
    continue
  fi

  trigger_short="${trigger_path##*/}"
  sub_path=$(gcloud eventarc triggers describe "$trigger_short" \
    --location="$REGION" \
    --project="$PROJECT" \
    --format='value(transport.pubsub.subscription)' 2>/dev/null || echo "")

  if [[ -z "$sub_path" ]]; then
    echo "⚠ $function_name: Eventarc trigger $trigger_short found but no transport subscription. Skipping."
    continue
  fi

  sub_name="${sub_path##*/}"

  # gcloud pubsub subscriptions update is idempotent — same
  # dead-letter-topic + same max-delivery-attempts → no change. So we
  # can re-run this script after every deploy.
  echo "→ $function_name (trigger=$trigger_short sub=$sub_name)"
  echo "    dead-letter-topic=$dlq_topic max-delivery-attempts=$max_attempts"

  gcloud pubsub subscriptions update "$sub_name" \
    --dead-letter-topic="$dlq_topic" \
    --dead-letter-topic-project="$PROJECT" \
    --max-delivery-attempts="$max_attempts" \
    --min-retry-delay="$RETRY_MIN_BACKOFF" \
    --max-retry-delay="$RETRY_MAX_BACKOFF" \
    --project="$PROJECT" \
    --quiet > /dev/null
done

echo
echo "✓ All triggers patched. To verify:"
echo "    gcloud pubsub subscriptions describe <sub-name> \\"
echo "      --project=$PROJECT --format='yaml(deadLetterPolicy)'"
