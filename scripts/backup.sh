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

# Persistent secrets are intentionally mode 0600 and usually owned by root
# because the service container creates them. Read the repository through a
# short-lived root container, but stream the archive to the host shell so the
# resulting file remains owned by the invoking user.
image=$(docker compose images -q sovereign 2>/dev/null | head -n 1)
if [[ -z "$image" ]]; then
  echo >&2 "ERROR: sovereign image is not available locally. Build or pull it before backup."
  exit 1
fi

docker run --rm \
  --entrypoint /bin/tar \
  -v "$PWD:/repo:ro" \
  "$image" \
  -C /repo -czf - data .env versions.env compose.yaml > "$out"

chmod 600 "$out"
sha256sum "$out" > "$out.sha256"

echo "Backup: $out"
echo "SHA256: $out.sha256"
echo "CRITICAL: archive contains PLANET/Controller identities, world signing keys, ztncui credentials/session state and application secrets. Store securely."
