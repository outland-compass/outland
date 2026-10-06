#!/usr/bin/env bash
# Disposable LOCAL Supabase only. Never accepts a remote URL.
set -euo pipefail
migration=${1:?migration file required}
db_container=$(docker ps --filter 'name=supabase_db_' --format '{{.ID}}' | head -n 1)
test -n "$db_container"
psql_local() { docker exec -i "$db_container" psql -X -v ON_ERROR_STOP=1 -U postgres -d postgres; }
reject() {
  local name=$1 setup=$2 expected=$3 out
  if out=$({ echo 'begin;'; echo "$setup"; cat "$migration"; echo 'rollback;'; } | psql_local 2>&1); then
    echo "ERROR: $name unexpectedly passed"; exit 1
  fi
  if ! grep -Fq "$expected" <<<"$out"; then
    echo "$out"; echo "ERROR: $name failed for an unexpected reason"; exit 1
  fi
  echo "PASS (expected rejection): $name"
}
reject 'missing audit' 'delete from infrastructure.base_legacy_migration_audit;' 'Base/audit parity failure'
reject 'changed Base' "update infrastructure.bases set name='changed';" 'Base/audit parity failure'
reject 'changed snapshot' "update infrastructure.base_legacy_migration_audit set source_snapshot=source_snapshot || '{\"name\":\"changed\"}'::jsonb;" 'Base/audit parity failure'
reject 'unexpected frontier' "insert into universe.frontiers(node_id,code,name) select id,'F','frontier' from universe.nodes;" 'unexpected nodes/frontiers/spots data'
reject 'unknown dependency' 'create view public.unexpected_consumer as select * from universe.nodes;' 'depend on it'
# Exercise cleanup AND recovery within a transaction and compare exact source rows.
{
 echo 'begin;'
 echo 'create temporary table source_before as select to_jsonb(n) as snapshot from universe.nodes n;'
 echo 'create temporary table bases_before as select to_jsonb(b) as snapshot from infrastructure.bases b;'
 cat "$migration"
 # Assertions normally open/rollback their own transaction; strip those wrappers here.
 sed '/^begin;$/d; /^rollback;$/d' supabase/tests/verify-sideworld-bases.sql
 cat scripts/legacy-cleanup/recover.sql
 cat <<'SQL'
do $$ begin
 if exists ((select snapshot from source_before except select to_jsonb(n) from universe.nodes n)
            union all (select to_jsonb(n) from universe.nodes n except select snapshot from source_before))
    or exists ((select snapshot from bases_before except select to_jsonb(b) from infrastructure.bases b)
            union all (select to_jsonb(b) from infrastructure.bases b except select snapshot from bases_before)) then
   raise exception 'Recovery changed source or Base rows';
 end if;
end $$;
rollback;
SQL
} | psql_local
echo 'PASS: cleanup, snapshot parity and recovery'
