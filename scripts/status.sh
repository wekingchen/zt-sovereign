#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

docker compose ps

echo
echo "--- ZeroTier Sovereign ---"
docker compose exec -T sovereign sovereignctl status || true

echo
echo "--- Versions ---"
docker compose exec -T sovereign sovereignctl version || true

echo
echo "--- Persistent paths ---"
du -sh data/planet data/controller data/postgres 2>/dev/null || true
