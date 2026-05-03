#!/bin/bash
export DATABASE_URL="postgres://superwizor_app:%7B%3DjDj%3D%3AG6Q%5DehAvs4mpet%2A0K%2B%5DP%26Ks%7B8@127.0.0.1:5432/superwizor?sslmode=disable"
export GCP_PROJECT_ID="superwizor-staging"
export AUDIO_BUCKET_NAME="superwizor-staging-audio-uploads"
export PORT=8082
cd services/ingestion-svc
go run cmd/server/main.go
