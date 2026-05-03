#!/bin/bash
export GCP_PROJECT_ID="superwizor-ai-25ecd"
export DATABASE_URL="postgres://superwizor_app:%7B%3DjDj%3D%3AG6Q%5DehAvs4mpet%2A0K%2B%5DP%26Ks%7B8@34.118.34.144:5432/superwizor?sslmode=require"
export PORT="8080"

cd "$(dirname "$0")/services/identity-svc"
go run ./cmd/server/main.go
