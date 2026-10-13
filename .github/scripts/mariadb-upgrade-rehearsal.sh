#!/usr/bin/env bash
# Rehearse a grimmory MariaDB image change the way the cluster will apply it:
#   1. old image initialises a data dir; grimmory's Flyway migrations build the
#      real schema in it, plus a canary row
#   2. the pre-upgrade dump hook script (from the new manifest) runs against it
#   3. the new image starts on the same data dir with the manifest's env
#   4. assert the upgrade ran, tables check clean, data survived, and grimmory
#      starts against the upgraded server
#
# usage: mariadb-upgrade-rehearsal.sh <base mariadb.yaml> <head mariadb.yaml> <grimmory.yaml>
set -euo pipefail

base_hr=$1 head_hr=$2 app_hr=$3

image() { yq -e ".spec.values.controllers.$2.containers.$2.image | .repository + \":\" + .tag" "$1"; }
old_image=$(image "$base_hr" mariadb)
new_image=$(image "$head_hr" mariadb)
dump_image=$(image "$head_hr" dump)
app_image=$(image "$app_hr" grimmory)
dump_script=$(yq -e '.spec.values.controllers.dump.containers.dump.args[0]' "$head_hr")
# Taken from the manifest, not hardcoded: dropping it is the bug this guards.
auto_upgrade=$(yq '.spec.values.controllers.mariadb.containers.mariadb.env.MARIADB_AUTO_UPGRADE // ""' "$head_hr")

echo "old:  $old_image"
echo "new:  $new_image"
echo "app:  $app_image"

pw=rehearsal
net=rehearsal
data=rehearsal-data
backups=rehearsal-backups
# Same hostname the cluster Service uses, so the dump script runs unmodified.
db=grimmory-mariadb

cleanup() {
  docker rm -f "$db" grimmory >/dev/null 2>&1 || true
  docker volume rm "$data" "$backups" >/dev/null 2>&1 || true
  docker network rm "$net" >/dev/null 2>&1 || true
}
trap cleanup EXIT
cleanup
docker network create "$net" >/dev/null
docker volume create "$data" >/dev/null
docker volume create "$backups" >/dev/null

fail() { echo "::error::$*"; exit 1; }

start_db() {
  docker run -d --name "$db" --network "$net" -v "$data:/var/lib/mysql" \
    -e MARIADB_ROOT_PASSWORD="$pw" -e MARIADB_DATABASE=grimmory \
    -e MARIADB_USER=grimmory -e MARIADB_PASSWORD="$pw" -e MARIADB_AUTO_UPGRADE="$auto_upgrade" \
    --health-cmd "healthcheck.sh --connect --innodb_initialized" \
    --health-interval 2s --health-retries 1 "$1" >/dev/null
  for _ in $(seq 120); do
    [ "$(docker inspect -f '{{.State.Health.Status}}' "$db")" = healthy ] && return
    [ "$(docker inspect -f '{{.State.Running}}' "$db")" = true ] || break
    sleep 2
  done
  docker logs "$db"
  fail "$1 never became healthy"
}

stop_db() { docker stop -t 60 "$db" >/dev/null && docker rm "$db" >/dev/null; }

sql() { docker exec "$db" mariadb -uroot -p"$pw" -N -e "$1"; }

start_app() {
  docker run -d --name grimmory --network "$net" -p 6060:6060 \
    -e DATABASE_HOST="$db" -e DATABASE_PORT=3306 -e DATABASE_NAME=grimmory \
    -e DATABASE_USERNAME=grimmory -e DATABASE_PASSWORD="$pw" \
    -e SWAGGER_ENABLED=false "$app_image" >/dev/null
  for _ in $(seq 90); do
    curl -fs -o /dev/null http://localhost:6060/api/v1/healthcheck && return
    [ "$(docker inspect -f '{{.State.Running}}' grimmory)" = true ] || break
    sleep 5
  done
  docker logs grimmory
  fail "grimmory did not become healthy against $1"
}

stop_app() { docker logs grimmory > "$1" 2>&1; docker rm -f grimmory >/dev/null; }

echo "::group::Seed data dir on $old_image"
start_db "$old_image"
start_app "$old_image"
stop_app app-before.log
sql "CREATE DATABASE ci_canary;
     CREATE TABLE ci_canary.t (id INT PRIMARY KEY, v VARCHAR(32));
     INSERT INTO ci_canary.t VALUES (1, 'survives-upgrade');"
tables_before=$(sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='grimmory'")
[ "$tables_before" -gt 0 ] || fail "Flyway created no tables in grimmory"
echo "grimmory tables: $tables_before"
echo "::endgroup::"

echo "::group::Pre-upgrade dump hook ($dump_image)"
docker run --rm --network "$net" -v "$backups:/backups" \
  -e MARIADB_ROOT_PASSWORD="$pw" -e DUMP_REQUIRED=true \
  --entrypoint /bin/bash "$dump_image" -c "$dump_script"
docker run --rm -v "$backups:/backups" --entrypoint /bin/bash "$dump_image" -c \
  'f=$(ls /backups/*.sql.zst) && zstd -dc "$f" | tail -n1 | grep -q "Dump completed"' \
  || fail "dump is missing or truncated"
echo "::endgroup::"

stop_db
info_before=$(docker run --rm -v "$data:/d" --entrypoint cat "$old_image" /d/mariadb_upgrade_info | tr -d '\0')

echo "::group::Upgrade to $new_image"
start_db "$new_image"
docker logs "$db" 2>&1 | grep -E "upgrade|Upgrade" || true
echo "::endgroup::"

version=$(sql "SELECT VERSION()")
info_after=$(docker run --rm -v "$data:/d" --entrypoint cat "$new_image" /d/mariadb_upgrade_info | tr -d '\0')
echo "server $version, mariadb_upgrade_info $info_before -> $info_after"
[ "${info_after%%-*}" = "${version%%-*}" ] \
  || fail "mariadb_upgrade_info is $info_after but the server is $version: mariadb-upgrade did not run"

echo "::group::mariadb-check"
check=$(docker exec "$db" mariadb-check -uroot -p"$pw" --all-databases --check-upgrade)
echo "$check"
echo "::endgroup::"
! grep -qiE "error|corrupt" <<<"$check" || fail "mariadb-check reported errors"

[ "$(sql "SELECT v FROM ci_canary.t WHERE id=1")" = survives-upgrade ] || fail "canary row lost"
tables_after=$(sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='grimmory'")
[ "$tables_after" = "$tables_before" ] || fail "grimmory tables: $tables_before before, $tables_after after"

echo "::group::grimmory against $new_image"
start_app "$new_image"
stop_app app-after.log
echo "::endgroup::"
# e.g. "Using MariaDB 13.0 which is newer than the version Flyway has been
# verified with." (logged by o.f.c.internal.database.base.Database)
if grep -iE "newer than the version Flyway|Flyway upgrade recommended|not supported by Flyway" app-after.log; then
  echo "::warning::Flyway in $app_image has not been tested against $version"
fi

echo "OK: $old_image -> $new_image"
