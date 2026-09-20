#!/usr/bin/env bash
# CI-only migration smoke test. Starts the base stack from the PR target branch,
# then switches to the ztncui-only candidate while preserving ZeroTier trust
# state. If the base already has ztncui state, preserve it too; if it predates
# ztncui (for example main v0.3.0), verify that the candidate initializes it
# securely on first boot.
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BASE_ROOT=/tmp/sovereign-base
cd "$ROOT"

: "${CI:?Refusing to run destructive upgrade test outside CI}"
: "${OLD_IMAGE:?OLD_IMAGE required}"
: "${NEW_IMAGE:?NEW_IMAGE required}"

wait_healthy() {
  local name=$1
  for _ in $(seq 1 180); do
    state=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || true)
    [[ "$state" == healthy ]] && return 0
    sleep 2
  done
  docker logs --tail=300 "$name" 2>/dev/null || true
  return 1
}

hash_file() {
  local name=$1 path=$2
  docker exec "$name" sha256sum "$path" | awk '{print $1}'
}

rm -rf "$ROOT/data" "$BASE_ROOT/data"
mkdir -p "$BASE_ROOT/data/planet"/{one,world,dist,config} "$BASE_ROOT/data/controller/one" "$BASE_ROOT/data/postgres" "$BASE_ROOT/data/ztncui"

# Start the old/base architecture from its own worktree so its Compose services
# and environment contract remain exactly as they were.
cp "$ROOT/.env" "$BASE_ROOT/.env"
sed -i 's/^SOVEREIGN_IMAGE=.*/SOVEREIGN_IMAGE=zerotier-sovereign:upgrade-old/' "$BASE_ROOT/.env"
sed -i 's/^ZTNCUI_PORT=.*/ZTNCUI_PORT=3002/' "$BASE_ROOT/.env"
grep -q '^POSTGRES_PASSWORD=' "$BASE_ROOT/.env" || echo 'POSTGRES_PASSWORD=upgrade-ci-only-password' >> "$BASE_ROOT/.env"
grep -q '^ZTNET_AUTH_SECRET=' "$BASE_ROOT/.env" || echo 'ZTNET_AUTH_SECRET=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef' >> "$BASE_ROOT/.env"
grep -q '^ZTNET_URL=' "$BASE_ROOT/.env" || echo 'ZTNET_URL=http://127.0.0.1:3000' >> "$BASE_ROOT/.env"

(
  cd "$BASE_ROOT"
  docker compose up -d --no-build
)
wait_healthy zerotier-sovereign

root_before=$(hash_file zerotier-sovereign /data/planet/one/identity.secret)
current_before=$(hash_file zerotier-sovereign /data/planet/world/current.c25519)
previous_before=$(hash_file zerotier-sovereign /data/planet/world/previous.c25519)
controller_before=$(hash_file zerotier-sovereign /data/controller/one/identity.secret)

base_has_ztncui=false
passwd_before=
session_before=
if docker exec zerotier-sovereign sh -lc 'test -s /data/ztncui/passwd && test -s /data/ztncui/session.secret' 2>/dev/null; then
  base_has_ztncui=true
  passwd_before=$(hash_file zerotier-sovereign /data/ztncui/passwd)
  session_before=$(hash_file zerotier-sovereign /data/ztncui/session.secret)
  echo "Base contains ztncui state; it will be preserved."
else
  echo "Base predates persistent ztncui state; candidate must initialize it securely."
fi

token=$(docker exec zerotier-sovereign sh -lc 'cat /data/controller/one/authtoken.secret' | tr -d '\r\n')
status=$(docker exec zerotier-sovereign curl -fsS -H "X-ZT1-Auth: $token" http://127.0.0.1:9993/status)
addr=$(printf '%s' "$status" | python3 -c 'import json,sys; print(json.load(sys.stdin)["address"])')
nwid="${addr}c1a0ee"
docker exec zerotier-sovereign curl -fsS \
  -H "X-ZT1-Auth: $token" -H 'Content-Type: application/json' \
  -X POST -d '{"name":"migration-persist-me"}' \
  "http://127.0.0.1:9993/controller/network/$nwid" >/dev/null

(
  cd "$BASE_ROOT"
  docker compose stop
)

# Move only state that belongs to the candidate architecture. Secret files are
# root-owned mode 0600, so copy them through the Docker daemon instead of
# reading bind mounts as the unprivileged GitHub runner. PostgreSQL is
# intentionally left behind: v0.4 no longer consumes it.
mkdir -p "$ROOT/data"
docker cp zerotier-sovereign:/data/planet "$ROOT/data/"
docker cp zerotier-sovereign:/data/controller "$ROOT/data/"
if [[ "$base_has_ztncui" == true ]]; then
  docker cp zerotier-sovereign:/data/ztncui "$ROOT/data/"
fi

# Base and candidate intentionally use the same stable container name. Remove
# the stopped base stack after extracting state so the candidate can claim it.
(
  cd "$BASE_ROOT"
  docker compose down
)

export SOVEREIGN_IMAGE="$NEW_IMAGE"
docker compose up -d --no-build sovereign
wait_healthy zerotier-sovereign

test "$root_before" = "$(hash_file zerotier-sovereign /data/planet/one/identity.secret)"
test "$current_before" = "$(hash_file zerotier-sovereign /data/planet/world/current.c25519)"
test "$previous_before" = "$(hash_file zerotier-sovereign /data/planet/world/previous.c25519)"
test "$controller_before" = "$(hash_file zerotier-sovereign /data/controller/one/identity.secret)"

if [[ "$base_has_ztncui" == true ]]; then
  test "$passwd_before" = "$(hash_file zerotier-sovereign /data/ztncui/passwd)"
  test "$session_before" = "$(hash_file zerotier-sovereign /data/ztncui/session.secret)"
else
  docker exec zerotier-sovereign sh -lc '
    test -s /data/ztncui/passwd
    test -s /data/ztncui/session.secret
    test -s /data/ztncui/initial-admin-password
    test "$(stat -c %a /data/ztncui/passwd)" = 600
    test "$(stat -c %a /data/ztncui/session.secret)" = 600
    test "$(stat -c %a /data/ztncui/initial-admin-password)" = 600
  '
fi

token=$(docker exec zerotier-sovereign sh -lc 'cat /data/controller/one/authtoken.secret' | tr -d '\r\n')
docker exec zerotier-sovereign curl -fsS \
  -H "X-ZT1-Auth: $token" \
  "http://127.0.0.1:9993/controller/network/$nwid" |
  grep -q 'migration-persist-me'

curl -fsS "http://127.0.0.1:${ZTNCUI_PORT:-3000}/" >/dev/null

if [[ "$base_has_ztncui" == true ]]; then
  echo "PASS architecture migration: ZeroTier and ztncui state preserved; PostgreSQL retired"
else
  echo "PASS architecture migration: ZeroTier state preserved; ztncui securely initialized; PostgreSQL retired"
fi
