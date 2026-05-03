#!/bin/bash
export GCP_PROJECT_ID="superwizor-ai-25ecd"
export AUDIO_BUCKET_NAME="superwizor-ai-25ecd-audio-uploads"
export DATABASE_URL="postgres://superwizor_app:%7B%3DjDj%3D%3AG6Q%5DehAvs4mpet%2A0K%2B%5DP%26Ks%7B8@34.118.34.144:5432/superwizor?sslmode=require"
export PORT="8082"
export SIGN_URL_SA_EMAIL="ingestion-svc@superwizor-ai-25ecd.iam.gserviceaccount.com"

cd "$(dirname "$0")/services/ingestion-svc"
go run ./cmd/server/main.go
