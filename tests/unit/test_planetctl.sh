#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/one" "$tmp/world" "$tmp/dist" "$tmp/config"

cat > "$tmp/bin/zerotier-idtool" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
case "$1" in
  generate)
    printf 'secret-key\n' > "$2"
    printf '8056c2e21c:0:public-material\n' > "$3"
    ;;
  initmoon)
    cat <<'JSON'
{"id":"8056c2e21c","roots":[{"identity":"8056c2e21c:0:public-material","stableEndpoints":[]}]}
JSON
    ;;
  genmoon)
    printf 'moon:%s\n' "$(sha256sum "$2" | awk '{print $1}')" > 0000008056c2e21c.moon
    ;;
  *) echo "unexpected idtool command: $*" >&2; exit 99 ;;
esac
MOCK
chmod +x "$tmp/bin/zerotier-idtool"

cat > "$tmp/bin/mkworld" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
ts=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --timestamp) ts=$2; shift 2 ;;
    *) shift ;;
  esac
done
[[ -n "$ts" ]]
[[ -s current.c25519 ]] || printf 'current-key\n' > current.c25519
[[ -s previous.c25519 ]] || printf 'previous-key\n' > previous.c25519
printf 'world:%s:%s\n' "$ts" "$(sha256sum moon.json | awk '{print $1}')" > world.bin
MOCK
chmod +x "$tmp/bin/mkworld"

export PLANET_HOME="$tmp/one"
export WORLD_DIR="$tmp/world"
export DIST_DIR="$tmp/dist"
export CONFIG_DIR="$tmp/config"
export PLANET_ZT_IDTOOL="$tmp/bin/zerotier-idtool"
export PLANET_MKWORLD="$tmp/bin/mkworld"
export PLANET_ZT_PORT=9994
export PLANET_IP_ADDR4=203.0.113.10
export PLANET_WORLD_TIMESTAMP=1000

ctl="$ROOT/rootfs/usr/local/bin/planetctl"
"$ctl" init >/dev/null

test -s "$tmp/dist/planet"
test -s "$tmp/world/current.c25519"
test -s "$tmp/world/previous.c25519"
test "$(cat "$tmp/world/timestamp")" = 1000
id_before=$(sha256sum "$tmp/one/identity.secret" | awk '{print $1}')
cur_before=$(sha256sum "$tmp/world/current.c25519" | awk '{print $1}')
planet_before=$(sha256sum "$tmp/dist/planet" | awk '{print $1}')

"$ctl" ensure >/dev/null
test "$id_before" = "$(sha256sum "$tmp/one/identity.secret" | awk '{print $1}')"

export PLANET_IP_ADDR4=203.0.113.11
# Deliberately request the same timestamp: planetctl must advance it monotonically.
export PLANET_WORLD_TIMESTAMP=1000
"$ctl" regenerate >/dev/null

test "$id_before" = "$(sha256sum "$tmp/one/identity.secret" | awk '{print $1}')"
test "$cur_before" = "$(sha256sum "$tmp/world/current.c25519" | awk '{print $1}')"
test "$(cat "$tmp/world/timestamp")" = 1001
test "$planet_before" != "$(sha256sum "$tmp/dist/planet" | awk '{print $1}')"
grep -q '203.0.113.11/9994' "$tmp/world/endpoints.json"

rm -f "$tmp/world/current.c25519"
set +e
"$ctl" ensure >/dev/null 2>&1
rc=$?
set -e
test "$rc" -eq 4

echo "PASS test_planetctl"
