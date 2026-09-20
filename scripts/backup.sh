#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

mkdir -p backup
stamp=$(date -u +%Y%m%dT%H%M%SZ)
out="backup/zerotier-sovereign-${stamp}.tar.gz"

was_running=0
if docker compose ps --status running --quiet | grep -q .; then
  was_running=1
  docker compose stop
fi
trap 'if [[ "$was_running" == 1 ]]; then docker compose start >/dev/null; fi' EXIT

tar -C . -czf "$out" data .env versions.env compose.yaml
chmod 600 "$out"
sha256sum "$out" > "$out.sha256"

echo "Backup: $out"
echo "SHA256: $out.sha256"
echo "CRITICAL: archive contains PLANET/Controller identities, world signing keys, ztncui credentials/session state and application secrets. Store securely."
