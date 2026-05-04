#!/bin/bash
PROJECT_ID="superwizor-ai-25ecd"
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")
PUBSUB_SA="serviceAccount:service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com"

# Allow Pub/Sub to invoke the Cloud Run functions created by Gen2 Cloud Functions
gcloud run services add-iam-policy-binding stt-worker \
  --region=europe-central2 \
  --member="$PUBSUB_SA" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding llm-worker \
  --region=europe-central2 \
  --member="$PUBSUB_SA" \
  --role="roles/run.invoker"
