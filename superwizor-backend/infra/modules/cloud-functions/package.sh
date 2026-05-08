#!/bin/bash
set -e

OUT_DIR="$(cd "$3" && pwd)"
RES_ID="$4"

# Ścieżka do głównego katalogu repozytorium
REPO_DIR="${PWD%%/superwizor-backend/*}/superwizor-backend"
AI_SVC_DIR="$REPO_DIR/services/ai-pipeline-svc"
NOTIFICATION_SVC_DIR="$REPO_DIR/services/notification-svc"

STT_DIR="$AI_SVC_DIR/cmd/stt-worker"
LLM_DIR="$AI_SVC_DIR/cmd/llm-worker"
NOTIFICATION_WORKER_DIR="$NOTIFICATION_SVC_DIR/cmd/worker"

echo "Packaging STT worker..."
rm -rf "$OUT_DIR/.tmp/stt-worker"
mkdir -p "$OUT_DIR/.tmp/stt-worker"
cp "$STT_DIR/main.go" "$OUT_DIR/.tmp/stt-worker/"
cp "$AI_SVC_DIR/go.mod" "$OUT_DIR/.tmp/stt-worker/"
cp "$AI_SVC_DIR/go.sum" "$OUT_DIR/.tmp/stt-worker/"

# Kopiowanie lokalnych zależności
cp -R "$REPO_DIR/pkg" "$OUT_DIR/.tmp/stt-worker/"
cp -R "$REPO_DIR/gen" "$OUT_DIR/.tmp/stt-worker/"

# Podmiana ścieżek w go.mod
cd "$OUT_DIR/.tmp/stt-worker"
sed -i.bak 's|=> ../../pkg|=> ./pkg|g' go.mod
sed -i.bak 's|=> ../../gen|=> ./gen|g' go.mod
rm -f go.mod.bak
rm -rf vendor
zip -r "../stt-worker-${RES_ID}.zip" .
cd "$AI_SVC_DIR"

echo "Packaging LLM worker..."
rm -rf "$OUT_DIR/.tmp/llm-worker"
mkdir -p "$OUT_DIR/.tmp/llm-worker"
cp "$LLM_DIR/main.go" "$OUT_DIR/.tmp/llm-worker/"
cp -R "$LLM_DIR/schemas" "$OUT_DIR/.tmp/llm-worker/"
cp "$AI_SVC_DIR/go.mod" "$OUT_DIR/.tmp/llm-worker/"
cp "$AI_SVC_DIR/go.sum" "$OUT_DIR/.tmp/llm-worker/"

# Kopiowanie lokalnych zależności
cp -R "$REPO_DIR/pkg" "$OUT_DIR/.tmp/llm-worker/"
cp -R "$REPO_DIR/gen" "$OUT_DIR/.tmp/llm-worker/"

# Podmiana ścieżek w go.mod
cd "$OUT_DIR/.tmp/llm-worker"
sed -i.bak 's|=> ../../pkg|=> ./pkg|g' go.mod
sed -i.bak 's|=> ../../gen|=> ./gen|g' go.mod
rm -f go.mod.bak
rm -rf vendor
zip -r "../llm-worker-${RES_ID}.zip" .
cd "$AI_SVC_DIR"

echo "Packaging notification worker..."
# Cloud Functions Gen2 Go runtime looks for the registered function in the
# package at the root of the deploy bundle (see llm/stt-worker layout above).
# Our worker source is at cmd/worker/main.go and imports
# internal/adapters/{postgres,firestore,fcm}. We hoist main.go to the root
# and bring the internal/ tree alongside it, so:
#
#   ./go.mod                              (module = notification-svc)
#   ./main.go                             (package notificationworker, with init())
#   ./internal/adapters/postgres/...      (resolved via module path)
#   ./internal/adapters/firestore/...
#   ./internal/adapters/fcm/...
#   ./gen/...   ./pkg/...                 (replace targets rewritten below)
#
# We deliberately omit cmd/server (it has func main() — would break the
# functions framework's package detection if mixed in).
rm -rf "$OUT_DIR/.tmp/notification-worker"
mkdir -p "$OUT_DIR/.tmp/notification-worker"
cp "$NOTIFICATION_SVC_DIR/go.mod" "$OUT_DIR/.tmp/notification-worker/"
cp "$NOTIFICATION_SVC_DIR/go.sum" "$OUT_DIR/.tmp/notification-worker/"
cp "$NOTIFICATION_WORKER_DIR/main.go" "$OUT_DIR/.tmp/notification-worker/"
cp -R "$NOTIFICATION_SVC_DIR/internal" "$OUT_DIR/.tmp/notification-worker/"

cp -R "$REPO_DIR/pkg" "$OUT_DIR/.tmp/notification-worker/"
cp -R "$REPO_DIR/gen" "$OUT_DIR/.tmp/notification-worker/"

cd "$OUT_DIR/.tmp/notification-worker"
sed -i.bak 's|=> ../../pkg|=> ./pkg|g' go.mod
sed -i.bak 's|=> ../../gen|=> ./gen|g' go.mod
rm -f go.mod.bak
rm -rf vendor
zip -r "../notification-worker-${RES_ID}.zip" .
cd "$NOTIFICATION_SVC_DIR"

echo "Packaging complete in $OUT_DIR"
