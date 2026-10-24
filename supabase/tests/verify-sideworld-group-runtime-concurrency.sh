#!/usr/bin/env bash
# Never run against remotely linked databases. ONLY the disposable Supabase
# Docker DB started by .github/workflows/group-runtime-sql-ci.yml.
# Two independent PostgreSQL sessions race for the last role and the same
# shared progress sequence. Synthetic fixtures only; disposable stack removed.
set -euo pipefail

db_container=$(docker ps --filter 'name=supabase_db_' --format '{{.ID}}' | head -n 1)
test -n "$db_container"
test -f supabase/tests/verify-sideworld-group-runtime-proposal.sql

# The reviewed fixture ends before its assertions. In this test the synthetic
# data must COMMIT so independent psql sessions can race it.
{
  printf 'BEGIN;\n'
  awk '/^do \$group_test\$/ {exit} {print}' \
    supabase/tests/verify-sideworld-group-runtime-proposal.sql
  printf 'COMMIT;\n'
} | docker exec -i "$db_container" psql -X -q -v ON_ERROR_STOP=1 -U postgres -d postgres >/dev/null

host="'ce100000-0000-4000-8000-000000000001'::uuid"
partner="'ce100000-0000-4000-8000-000000000002'::uuid"
stranger="'ce100000-0000-4000-8000-000000000003'::uuid"
release="'ce800000-0000-4000-8000-000000000001'::uuid"
initial="jsonb_build_object('engineVersion',1,'questId','ce600000-0000-4000-8000-000000000001','revision',1,'contentHash',repeat('a',64),'sequence',0,'events','[]'::jsonb)"
next="jsonb_build_object('engineVersion',1,'questId','ce600000-0000-4000-8000-000000000001','revision',1,'contentHash',repeat('a',64),'sequence',1,'events',jsonb_build_array(jsonb_build_object('type','arrive')))"
psql_query () {
  docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres -c "$1"
}

# Entitle an additional real-fixture user, never a forged role or client key.
psql_query "insert into player.qa_access(release_id,actor_id,expires_at,granted_by)
  values($release,$stranger,now()+interval '1 hour',$host)" >/dev/null

session_id=$(psql_query "select public.sideworld_group_create_v1(
  $host,$release,'couple','ce900000-0000-4000-8000-000000000051'::uuid,
  $initial,repeat('b',64),now()+interval '30 minutes')->>'sessionId'")
[[ "$session_id" =~ ^[[:xdigit:]-]{36}$ ]]

out_a=$(mktemp)
out_b=$(mktemp)
trap 'rm -f "$out_a" "$out_b"' EXIT

# A holds group_sessions FOR UPDATE for two seconds after its successful join.
# B must wait and observe a FULL lobby; never get a duplicate role.
docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "BEGIN; SELECT public.sideworld_group_join_v1(
    $partner,'$session_id'::uuid,repeat('b',64))->>'kind';
    SELECT pg_sleep(2); COMMIT;" > "$out_a" &
pid_a=$!
sleep 0.30
docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "SELECT public.sideworld_group_join_v1(
    $stranger,'$session_id'::uuid,repeat('b',64))->>'kind';" > "$out_b" &
pid_b=$!
wait "$pid_a"
wait "$pid_b"

outcomes=$(grep -hE '^(joined|unavailable)$' "$out_a" "$out_b" | sort)
expected=$(printf 'joined\nunavailable')
if [[ "$outcomes" != "$expected" ]]; then
  echo "Join race must yield exactly one joined + one unavailable: $outcomes" >&2
  exit 1
fi
count=$(psql_query "select count(*) from player.group_members where session_id='$session_id'::uuid")
unique_roles=$(psql_query "select count(distinct role_id) from player.group_members where session_id='$session_id'::uuid")
status=$(psql_query "select status from player.group_sessions where id='$session_id'::uuid")
[[ "$count" == "2" && "$unique_roles" == "2" && "$status" == "in_progress" ]]

# Two DIFFERENT members race different commands with expectedSequence=0.
# The SQL CAS must save exactly one advance and exactly one receipt.
docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "BEGIN; SELECT public.sideworld_group_apply_v1(
    $host,'$session_id'::uuid,'ce900000-0000-4000-8000-000000000052'::uuid,
    repeat('d',64),0,$next,false)->>'kind';
    SELECT pg_sleep(2); COMMIT;" > "$out_a" &
pid_a=$!
sleep 0.30
docker exec "$db_container" psql -X -qAt -v ON_ERROR_STOP=1 -U postgres -d postgres \
  -c "SELECT public.sideworld_group_apply_v1(
    $partner,'$session_id'::uuid,'ce900000-0000-4000-8000-000000000053'::uuid,
    repeat('e',64),0,$next,false)->>'kind';" > "$out_b" &
pid_b=$!
wait "$pid_a"
wait "$pid_b"
outcomes=$(grep -hE '^(saved|conflict)$' "$out_a" "$out_b" | sort)
expected=$(printf 'conflict\nsaved')
if [[ "$outcomes" != "$expected" ]]; then
  echo "CAS race must yield exactly one saved + one conflict: $outcomes" >&2
  exit 1
fi
sequence=$(psql_query "select sequence from player.group_sessions where id='$session_id'::uuid")
receipts=$(psql_query "select count(*) from player.group_receipts where session_id='$session_id'::uuid")
[[ "$sequence" == "1" && "$receipts" == "1" ]]

# Expired invites cannot grant another actor membership, even if the hash matches.
second_id=$(psql_query "select public.sideworld_group_create_v1(
  $host,$release,'couple','ce900000-0000-4000-8000-000000000054'::uuid,
  $initial,repeat('c',64),now()+interval '30 minutes')->>'sessionId'")
[[ "$second_id" =~ ^[[:xdigit:]-]{36}$ ]]
psql_query "update player.group_sessions set invite_expires_at=now()-interval '1 second'
  where id='$second_id'::uuid" >/dev/null
expired=$(psql_query "select public.sideworld_group_join_v1(
  $partner,'$second_id'::uuid,repeat('c',64))->>'kind'")
[[ "$expired" == "unavailable" ]]

echo "PASS: independent SQL sessions serialized joins, role uniqueness, CAS receipts and expiry"
