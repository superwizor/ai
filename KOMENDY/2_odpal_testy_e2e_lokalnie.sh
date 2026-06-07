#!/usr/bin/env bash
# 2_odpal_testy_e2e_lokalnie.sh
set -e
echo "🧪 Uruchamianie lokalnych testów E2E..."
cd "$(dirname "$0")/../superwizor-backend"
make test-e2e-local
