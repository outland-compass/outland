#!/usr/bin/env bash
# Disposable GitHub/local Supabase ONLY. Synthetic test data is committed to the
# ephemeral database so two INDEPENDENT PostgreSQL sessions can race one run.
# The CI job stops/destroys the whole disposable stack after this test.
set -euo pipefail

db_container=$(docker ps --filter 'name=supabase_db_' --format '{{.ID}}' | head -n 1)
test -n "$db_container"
fixture='supabase/tests/verify-sideworld-player-runtime-transactions.sql'
test -f "$fixture"

# Reuse the reviewed synthetic fixture INSERT statements, WITHOUT its outer
# BEGIN/ROLLBACK or DO assertions. Never source production data.
# Avoid executing the later audit-only assertions in this separately committed concurrency fixture.
awk '/^insert into auth.users\(/ {copy=1} /^do \$test\$/ {copy=0} /^-- Audit migration is optional/ {copy=0} copy {print}' "$fixture" |
  docker exec -i "$db_container" psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres

actor="'dd100000-0000-4000-8000-000000000001'::uuid"
release="'dd800000-0000-4000-8000-000000000001'::uuid"
initial="jsonb_build_object('engineVersion',1,'questId','dd600000-0000-4000-8000-000000000001','revision',1,'contentHash',repeat('a',64),'sequence',0,'events','[]'::jsonb)"
next="jsonb_build_object('engineVersion',1,'questId','dd600000-0000-4000-8000-000000000001','revision',1,'contentHash',repeat('a',64),'sequence',1,'events',jsonb_build_array(jsonb_build_object('type','arrive')))"

run_id=$(docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "select public.sideworld_player_run_start_v1($actor,$release,'dd900000-0000-4000-8000-000000000041'::uuid,$initial)->>'runId'")
if [[ ! "$run_id" =~ ^[[:xdigit:]-]{36}$ ]]; then
  echo 'No run created for concurrency test' >&2
  exit 1
fi

out_a=$(mktemp)
out_b=$(mktemp)
trap 'rm -f "$out_a" "$out_b"' EXIT

# Transaction A intentionally retains the FOR UPDATE lock during pg_sleep.
# Transaction B must WAIT and then observe the advanced sequence; one success.
docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "BEGIN; SELECT public.sideworld_player_run_apply_v1($actor,'$run_id'::uuid,'dd900000-0000-4000-8000-000000000042'::uuid,repeat('b',64),0,$next)->>'kind'; SELECT pg_sleep(2); COMMIT;" > "$out_a" &
pid_a=$!
sleep 0.25
docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "SELECT public.sideworld_player_run_apply_v1($actor,'$run_id'::uuid,'dd900000-0000-4000-8000-000000000043'::uuid,repeat('c',64),0,$next)->>'kind';" > "$out_b" &
pid_b=$!

wait "$pid_a"
wait "$pid_b"

outcomes=$(grep -hE '^(saved|conflict)$' "$out_a" "$out_b" | sort)
expected=$(printf 'conflict\nsaved')
if [[ "$outcomes" != "$expected" ]]; then
  echo "Expected one saved and one conflict, got: $outcomes" >&2
  exit 1
fi

sequence=$(docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "select sequence from player.quest_runs where id='$run_id'::uuid")
receipts=$(docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "select count(*) from player.run_receipts where run_id='$run_id'::uuid")
if [[ "$sequence" != "1" || "$receipts" != "1" ]]; then
  echo "Atomicity failure: sequence=$sequence receipts=$receipts" >&2
  exit 1
fi

echo 'PASS: two separate Postgres sessions, one committed advance, one conflict, one receipt.'
