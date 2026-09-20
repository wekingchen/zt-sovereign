#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "Created .env from .env.example"
fi
mkdir -p data/planet/{one,world,dist,config} data/controller/one data/ztncui
chmod 700 data/planet/one data/planet/world data/planet/config data/controller/one 2>/dev/null || true

cat <<'TXT'
Initialization complete.

Next:
  1. Edit .env and set PLANET_IP_ADDR4 and/or PLANET_IP_ADDR6.
  2. Replace ZTNET_AUTH_SECRET and POSTGRES_PASSWORD with strong unique values.
  3. Set ZTNET_URL to the exact URL used to access ZTNet.
  4. Run: ./scripts/verify.sh
  5. Local source build: ./scripts/build-local.sh
  6. Start: docker compose up -d
TXT
