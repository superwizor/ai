#!/bin/bash
# scripts/dns_helper.sh - Helper script to query custom domain settings from Firebase Hosting API.
set -e

PROJECT_ID="superwizor-ai-25ecd"
TOKEN=$(gcloud auth print-access-token)

echo "=== Firebase Hosting Domain Status ==="
echo "Querying superwizor.ai (site: superwizor)..."
curl -s -H "X-Goog-User-Project: $PROJECT_ID" -H "Authorization: Bearer $TOKEN" \
  "https://firebasehosting.googleapis.com/v1beta1/projects/$PROJECT_ID/sites/superwizor/domains/superwizor.ai"

echo -e "\n----------------------------------------\n"

echo "Querying app.superwizor.ai (site: superwizor-app)..."
curl -s -H "X-Goog-User-Project: $PROJECT_ID" -H "Authorization: Bearer $TOKEN" \
  "https://firebasehosting.googleapis.com/v1beta1/projects/$PROJECT_ID/sites/superwizor-app/domains/app.superwizor.ai"
