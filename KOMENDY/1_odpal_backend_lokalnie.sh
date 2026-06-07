#!/usr/bin/env bash
# 1_odpal_backend_lokalnie.sh
set -e
echo "🔄 Uruchamianie lokalnego backendu SuperWizor..."
cd "$(dirname "$0")/../superwizor-backend"
./scripts/run_local_backend.sh
