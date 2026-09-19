#!/usr/bin/env bash
# CI-only upgrade smoke test. Reuses the same PostgreSQL + persistent ZeroTier data
# while switching from OLD_IMAGE to NEW_IMAGE.
set -Eeuo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
: "${CI:?Refusing to run destructive upgrade test outside CI}"
: "${OLD_IMAGE:?OLD_IMAGE required}"
: "${NEW_IMAGE:?NEW_IMAGE required}"

wait_healthy() {
  for _ in $(seq 1 180); do
    state=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' zerotier-sovereign 2>/dev/null || true)
    [[ "$state" == healthy ]] && return 0
    sleep 2
  done
  docker compose logs --no-color --tail=300 || true
  return 1
}

rm -rf data
mkdir -p data/planet/{one,world,dist,config} data/controller/one data/postgres

export SOVEREIGN_IMAGE="$OLD_IMAGE"
docker compose up -d --no-build postgres sovereign
wait_healthy
before=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-ztnet}" -d "${POSTGRES_DB:-ztnet}" -Atqc 'select count(*) from "_prisma_migrations";')
# A project-owned sentinel verifies the DB volume itself survives the application image switch.
docker compose exec -T postgres psql -U "${POSTGRES_USER:-ztnet}" -d "${POSTGRES_DB:-ztnet}" -v ON_ERROR_STOP=1 -c \
  'create table if not exists sovereign_upgrade_probe(id integer primary key, note text); insert into sovereign_upgrade_probe values (1, '\''persist-me'\'') on conflict (id) do update set note=excluded.note;' >/dev/null

docker compose stop sovereign
export SOVEREIGN_IMAGE="$NEW_IMAGE"
docker compose up -d --no-build sovereign
wait_healthy
after=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-ztnet}" -d "${POSTGRES_DB:-ztnet}" -Atqc 'select count(*) from "_prisma_migrations";')
probe=$(docker compose exec -T postgres psql -U "${POSTGRES_USER:-ztnet}" -d "${POSTGRES_DB:-ztnet}" -Atqc 'select note from sovereign_upgrade_probe where id=1;')

test "$probe" = persist-me
[[ "$before" =~ ^[0-9]+$ && "$after" =~ ^[0-9]+$ ]]
(( after >= before ))
curl -fsS http://127.0.0.1:${ZTNET_PORT:-3000}/ >/dev/null

echo "PASS upgrade smoke: migrations $before -> $after"
