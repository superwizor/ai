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

echo "Packaging STT worker (shared zip: stt-submit + stt-finalize + stt-watchdog)..."
# Single zip bundles three Cloud Function entry points registered in
# the sttworker package via init() — see cmd/stt-worker/{main.go,
# finalize.go, watchdog.go}. Each Cloud Functions Gen2 resource in
# terraform points at the same zip but with a different
# build_config.entry_point. Per Open Q4 in
# docs/13_STT_GCS_CALLBACK_AND_CHUNKING.md.
rm -rf "$OUT_DIR/.tmp/stt-worker"
mkdir -p "$OUT_DIR/.tmp/stt-worker"
# Glob all .go files (main.go, finalize.go, watchdog.go, stt_operations.go).
# Excludes _test.go via the shell glob behavior + post-copy cleanup.
cp "$STT_DIR"/*.go "$OUT_DIR/.tmp/stt-worker/"
# Test files don't belong in the deploy zip — they import testing and
# inflate the dependency graph.
rm -f "$OUT_DIR/.tmp/stt-worker/"*_test.go
cp "$AI_SVC_DIR/go.mod" "$OUT_DIR/.tmp/stt-worker/"
cp "$AI_SVC_DIR/go.sum" "$OUT_DIR/.tmp/stt-worker/"

# Kopiowanie lokalnych zależności
cp -R "$REPO_DIR/pkg" "$OUT_DIR/.tmp/stt-worker/"
cp -R "$REPO_DIR/gen" "$OUT_DIR/.tmp/stt-worker/"

# ai-pipeline-svc/internal — needed since feat/llm-optimisation
# wired stt-worker through internal/transcriptfmt (BCP47ize + the
# Chirp3DiarizationLanguages allow-list). Cloud Build can't resolve
# internal/* imports unless they're inside the zip; same pattern as
# the notification-worker section below.
cp -R "$AI_SVC_DIR/internal" "$OUT_DIR/.tmp/stt-worker/"

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
# Glob all .go files (main.go, rag.go — the docs/30 ranking core).
# Test files stripped post-copy, same as the stt-worker section above.
cp "$LLM_DIR"/*.go "$OUT_DIR/.tmp/llm-worker/"
rm -f "$OUT_DIR/.tmp/llm-worker/"*_test.go
cp -R "$LLM_DIR/schemas" "$OUT_DIR/.tmp/llm-worker/"
cp "$AI_SVC_DIR/go.mod" "$OUT_DIR/.tmp/llm-worker/"
cp "$AI_SVC_DIR/go.sum" "$OUT_DIR/.tmp/llm-worker/"

# Kopiowanie lokalnych zależności
cp -R "$REPO_DIR/pkg" "$OUT_DIR/.tmp/llm-worker/"
cp -R "$REPO_DIR/gen" "$OUT_DIR/.tmp/llm-worker/"

# ai-pipeline-svc/internal — needed since feat/llm-optimisation
# wired llm-worker through internal/transcriptfmt (Format A/B
# renderers) and internal/diarization (Markdown call-1 parser).
# Without this, the Cloud Build go-functions-framework can't resolve
# the imports and tries to fetch them from github.com (which fails
# because the repo is private).
cp -R "$AI_SVC_DIR/internal" "$OUT_DIR/.tmp/llm-worker/"

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
