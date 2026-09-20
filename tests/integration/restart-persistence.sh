#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

hash_in_container() {
  docker compose exec -T sovereign sha256sum "$1" | awk '{print $1}'
}

root_before=$(hash_in_container /data/planet/one/identity.secret)
current_before=$(hash_in_container /data/planet/world/current.c25519)
previous_before=$(hash_in_container /data/planet/world/previous.c25519)
controller_before=$(hash_in_container /data/controller/one/identity.secret)
ztncui_passwd_before=$(hash_in_container /data/ztncui/passwd)
ztncui_session_before=$(hash_in_container /data/ztncui/session.secret)

docker compose restart sovereign >/dev/null
for _ in $(seq 1 120); do
  state=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' zerotier-sovereign 2>/dev/null || true)
  [[ "$state" == healthy ]] && break
  sleep 2
done
[[ "$(docker inspect --format '{{.State.Health.Status}}' zerotier-sovereign)" == healthy ]]

test "$root_before" = "$(hash_in_container /data/planet/one/identity.secret)"
test "$current_before" = "$(hash_in_container /data/planet/world/current.c25519)"
test "$previous_before" = "$(hash_in_container /data/planet/world/previous.c25519)"
test "$controller_before" = "$(hash_in_container /data/controller/one/identity.secret)"
test "$ztncui_passwd_before" = "$(hash_in_container /data/ztncui/passwd)"
test "$ztncui_session_before" = "$(hash_in_container /data/ztncui/session.secret)"

echo "PASS restart persistence"
