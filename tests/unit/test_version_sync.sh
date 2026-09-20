#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
./scripts/sync-version-files.sh
# Every tracked build pin should match versions.env after sync.
set -a
# shellcheck disable=SC1091
source ./versions.env
set +a
for kv in \
  "SOVEREIGN_VERSION=$SOVEREIGN_VERSION" \
  "PLANET_ZEROTIER_VERSION=$PLANET_ZEROTIER_VERSION" \
  "PLANET_ZEROTIER_SOURCE_REF=$PLANET_ZEROTIER_SOURCE_REF" \
  "CONTROLLER_ZEROTIER_VERSION=$CONTROLLER_ZEROTIER_VERSION" \
  "CONTROLLER_ZEROTIER_SOURCE_REF=$CONTROLLER_ZEROTIER_SOURCE_REF" \
  "MKWORLD_SOURCE_REF=$MKWORLD_SOURCE_REF" \
  "NODEJS_IMAGE=$NODEJS_IMAGE"; do
  grep -Fxq "$kv" .env.example || { echo "missing synced pin: $kv" >&2; exit 1; }
done
echo "PASS test_version_sync"
