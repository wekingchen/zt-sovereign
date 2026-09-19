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
  generate) printf 'secret-key\n' > "$2"; printf '8056c2e21c:0:public-material\n' > "$3" ;;
  initmoon) printf '%s\n' '{"id":"8056c2e21c","roots":[{"identity":"8056c2e21c:0:public-material","stableEndpoints":[]}]}' ;;
  genmoon) printf 'moon:%s\n' "$(sha256sum "$2" | awk '{print $1}')" > 0000008056c2e21c.moon ;;
  *) echo "unexpected idtool command: $*" >&2; exit 99 ;;
esac
MOCK
chmod +x "$tmp/bin/zerotier-idtool"
cat > "$tmp/bin/ztmkworld" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
cfg=''
while [[ $# -gt 0 ]]; do case "$1" in -c) cfg=$2; shift 2 ;; *) shift ;; esac; done
[[ -n "$cfg" && -s "$cfg" ]]
readarray -t vals < <(python3 - "$cfg" <<'PY'
import json, sys
c=json.load(open(sys.argv[1], encoding='utf-8'))
print(c['plBirth']); print(c['output'])
PY
)
ts=${vals[0]}; out=${vals[1]}
[[ -s current.c25519 ]] || head -c 128 /dev/zero > current.c25519
[[ -s previous.c25519 ]] || head -c 128 /dev/zero > previous.c25519
printf 'world:%s:%s\n' "$ts" "$(sha256sum "$cfg" | awk '{print $1}')" > "$out"
MOCK
chmod +x "$tmp/bin/ztmkworld"
export PLANET_HOME="$tmp/one" WORLD_DIR="$tmp/world" DIST_DIR="$tmp/dist" CONFIG_DIR="$tmp/config"
export PLANET_ZT_IDTOOL="$tmp/bin/zerotier-idtool" PLANET_MKWORLD="$tmp/bin/ztmkworld"
export PLANET_ZT_PORT=9994 PLANET_IP_ADDR4=203.0.113.10 PLANET_WORLD_TIMESTAMP=1000
ctl="$ROOT/rootfs/usr/local/bin/planetctl"
"$ctl" init >/dev/null
test -s "$tmp/dist/planet"
test "$(wc -c < "$tmp/world/current.c25519")" -eq 128
test "$(cat "$tmp/world/timestamp")" = 1000
id_before=$(sha256sum "$tmp/one/identity.secret" | awk '{print $1}')
cur_before=$(sha256sum "$tmp/world/current.c25519" | awk '{print $1}')
planet_before=$(sha256sum "$tmp/dist/planet" | awk '{print $1}')
"$ctl" ensure >/dev/null
test "$id_before" = "$(sha256sum "$tmp/one/identity.secret" | awk '{print $1}')"
export PLANET_IP_ADDR4=203.0.113.11 PLANET_WORLD_TIMESTAMP=1000
"$ctl" regenerate >/dev/null
test "$id_before" = "$(sha256sum "$tmp/one/identity.secret" | awk '{print $1}')"
test "$cur_before" = "$(sha256sum "$tmp/world/current.c25519" | awk '{print $1}')"
test "$(cat "$tmp/world/timestamp")" = 1001
test "$planet_before" != "$(sha256sum "$tmp/dist/planet" | awk '{print $1}')"
grep -q '203.0.113.11/9994' "$tmp/world/endpoints.json"
grep -q '"plBirth": 1001' "$tmp/world/mkworld.config.json"
rm -f "$tmp/world/current.c25519"
set +e; "$ctl" ensure >/dev/null 2>&1; rc=$?; set -e
test "$rc" -eq 4
echo "PASS test_planetctl"
