#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."

[[ -f .env ]] || { echo >&2 "ERROR: .env missing. Run ./scripts/init.sh first."; exit 1; }
set -a
# shellcheck disable=SC1091
source ./.env
set +a

if [[ -z "${PLANET_IP_ADDR4:-}" && -z "${PLANET_IP_ADDR6:-}" ]]; then
  echo >&2 "ERROR: PLANET_IP_ADDR4 and PLANET_IP_ADDR6 are both empty."
  exit 1
fi
case "${ZTNET_AUTH_SECRET:-}" in
  ""|CHANGE_ME*) echo >&2 "ERROR: set a unique ZTNET_AUTH_SECRET (openssl rand -hex 32)."; exit 1 ;;
esac
case "${POSTGRES_PASSWORD:-}" in
  ""|CHANGE_ME*) echo >&2 "ERROR: set a strong POSTGRES_PASSWORD."; exit 1 ;;
esac
[[ -n "${ZTNET_URL:-}" ]] || { echo >&2 "ERROR: ZTNET_URL is empty."; exit 1; }
command -v docker >/dev/null || { echo >&2 "ERROR: docker not found."; exit 1; }
docker compose version >/dev/null
docker compose config -q

echo "OK: Compose syntax, PLANET endpoint, ZTNet URL and secrets look valid."
echo "NOTE: expose UDP/TCP ${PLANET_ZT_PORT:-9994} for PLANET and UDP ${CONTROLLER_ZT_PORT:-9993} for Controller VL1 traffic."
echo "NOTE: Controller HTTP API is internal-only; ZTNet talks to 127.0.0.1 inside the business container."
echo "NOTE: ZTNet UI and PLANET file service are loopback-only by default on the host."
