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
  docker compose logs --no-color --tail=300 sovereign || true
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

curl -fsS "http://127.0.0.1:${ZTNCUI_PORT:-3000}/" >/dev/null

# Verify the vendored ztncui controller client against the real Controller API.
docker compose exec -T sovereign sh -lc '
  cd /opt/ztncui
  export ZT_ADDR=http://127.0.0.1:9993
  export ZT_TOKEN="$(cat /data/controller/one/authtoken.secret)"
  node <<'"'"'JS'"'"'
const zt = require("./controllers/zt");
(async () => {
  const created = await zt.network_create({name: "ztncui-ci-smoke"});
  if (!created || !created.nwid) throw new Error("ztncui did not create a network");
  const listed = await zt.network_list();
  if (!listed.some((n) => n.nwid === created.nwid)) throw new Error("ztncui network missing from list");
  const detail = await zt.network_detail(created.nwid);
  if (detail.name !== "ztncui-ci-smoke") throw new Error("unexpected ztncui network detail");
  await zt.network_delete(created.nwid);
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
JS
'

# First boot must use a unique bootstrap password, never upstream admin/password.
initial_password=$(docker compose exec -T sovereign sovereignctl ztncui-initial-password | tr -d '\r\n')
[[ ${#initial_password} -ge 20 ]]

headers=$(mktemp)
cookies=$(mktemp)
curl -sS -D "$headers" -o /dev/null -c "$cookies" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'username=admin' \
  --data-urlencode "password=$initial_password" \
  "http://127.0.0.1:${ZTNCUI_PORT:-3000}/login"
grep -Eq '^HTTP/[^ ]+ 302' "$headers"
grep -Eqi '^location: /users/admin/password' "$headers"

new_password='Sovereign-CI-Admin-Change-2026!'
curl -fsS -b "$cookies" -c "$cookies" \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'username=admin' \
  --data-urlencode "password1=$new_password" \
  --data-urlencode "password2=$new_password" \
  "http://127.0.0.1:${ZTNCUI_PORT:-3000}/users/admin/password" >/dev/null

if docker compose exec -T sovereign sovereignctl ztncui-initial-password >/dev/null 2>&1; then
  echo >&2 "bootstrap password file still exists after admin password change"
  exit 1
fi

rm -f "$headers" "$cookies"
headers=$(mktemp)
curl -sS -D "$headers" -o /dev/null \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'username=admin' \
  --data-urlencode "password=$new_password" \
  "http://127.0.0.1:${ZTNCUI_PORT:-3000}/login"
grep -Eq '^HTTP/[^ ]+ 302' "$headers"
grep -Eqi '^location: /controller' "$headers"
rm -f "$headers"

# Recovery path: reset an already-changed admin password, rotate sessions,
# restart ztncui/container, and verify the replacement credential works.
reset_output=$(docker compose exec -T sovereign sovereignctl ztncui-reset-password --generate --no-restart)
reset_password=$(printf '%s\n' "$reset_output" | sed -n 's/^New password: //p')
[[ ${#reset_password} -ge 20 ]]
printf '%s\n' "$reset_output" | grep -q '^ztncui password reset successfully for user: adminprintf '%s\n' "$reset_output" | grep -q '^Container restart skipped\.'

docker compose restart sovereign >/dev/null
wait_healthy

headers=$(mktemp)
curl -sS -D "$headers" -o /dev/null \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'username=admin' \
  --data-urlencode "password=$reset_password" \
  "http://127.0.0.1:${ZTNCUI_PORT:-3000}/login"
grep -Eq '^HTTP/[^ ]+ 302' "$headers"
grep -Eqi '^location: /controller' "$headers"
rm -f "$headers"

if docker compose exec -T sovereign test -e /data/ztncui/initial-admin-password; then
  echo >&2 "bootstrap password file reappeared after reset"
  exit 1
fi

echo "PASS integration smoke"

printf '%s\n' "$reset_output" | grep -q '^Container restart skipped\.'

docker compose restart sovereign >/dev/null
wait_healthy

headers=$(mktemp)
curl -sS -D "$headers" -o /dev/null \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'username=admin' \
  --data-urlencode "password=$reset_password" \
  "http://127.0.0.1:${ZTNCUI_PORT:-3000}/login"
grep -Eq '^HTTP/[^ ]+ 302' "$headers"
grep -Eqi '^location: /controller' "$headers"
rm -f "$headers"

if docker compose exec -T sovereign test -e /data/ztncui/initial-admin-password; then
  echo >&2 "bootstrap password file reappeared after reset"
  exit 1
fi

echo "PASS integration smoke"
