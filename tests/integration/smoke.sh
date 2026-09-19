#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

wait_healthy() {
  for _ in $(seq 1 180); do
    state=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' zerotier-sovereign 2>/dev/null || true)
    [[ "$state" == healthy ]] && return 0
    [[ "$state" == unhealthy ]] && break
    sleep 2
  done
  docker compose ps || true
  docker compose logs --no-color --tail=300 sovereign postgres || true
  return 1
}

wait_healthy

docker compose exec -T sovereign sovereignctl version
docker compose exec -T sovereign sovereignctl health

docker compose exec -T sovereign test -s /data/planet/dist/planet
docker compose exec -T sovereign test -s /data/planet/world/current.c25519
docker compose exec -T sovereign test -s /data/planet/world/previous.c25519
docker compose exec -T sovereign cmp -s /data/planet/dist/planet /data/planet/one/planet
docker compose exec -T sovereign cmp -s /data/planet/dist/planet /data/controller/one/planet

# Exercise the real standalone Controller API: create/read/delete a temporary network.
token=$(docker compose exec -T sovereign sh -lc 'cat /data/controller/one/authtoken.secret' | tr -d '\r\n')
status=$(docker compose exec -T sovereign curl -fsS -H "X-ZT1-Auth: $token" http://127.0.0.1:9993/status)
addr=$(printf '%s' "$status" | python3 -c 'import json,sys; print(json.load(sys.stdin)["address"])')
nwid="${addr}c1a0ff"

docker compose exec -T sovereign curl -fsS \
  -H "X-ZT1-Auth: $token" -H 'Content-Type: application/json' \
  -X POST -d '{"name":"sovereign-ci-smoke"}' \
  "http://127.0.0.1:9993/controller/network/$nwid" >/dev/null

docker compose exec -T sovereign curl -fsS \
  -H "X-ZT1-Auth: $token" \
  "http://127.0.0.1:9993/controller/network/$nwid" \
  | grep -q 'sovereign-ci-smoke'

docker compose exec -T sovereign curl -fsS \
  -H "X-ZT1-Auth: $token" \
  -X DELETE "http://127.0.0.1:9993/controller/network/$nwid" >/dev/null

curl -fsS "http://127.0.0.1:${ZTNET_PORT:-3000}/" >/dev/null

# Prisma migrations must have been applied to PostgreSQL.
docker compose exec -T postgres psql -U "${POSTGRES_USER:-ztnet}" -d "${POSTGRES_DB:-ztnet}" -Atqc \
  'select count(*) from "_prisma_migrations";' | grep -Eq '^[1-9][0-9]*$'

echo "PASS integration smoke"
