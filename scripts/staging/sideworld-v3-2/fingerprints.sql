-- SIDEWORLD V3.2 staging rehearsal: READ-ONLY fingerprints of everything the four V3.2 migrations must not change.
-- Writes CSVs to /out (client side). The same file produces the backup baseline, the pre-apply freshness check and
-- the post-apply comparison, so the outputs are byte-comparable before and after the deployment.
--   * every table of every application schema EXCEPT universe/geo/canon (the V3.2 schemas) -> per-table count+md5;
--   * per-row md5 of the OUTLAND tables named in the rehearsal plan;
--   * schema- and table-privilege snapshot of the API roles on the application schemas.
-- psql variable scope: 'app' (default; used against staging) or 'all' (also auth/storage; local restores only).
\set ON_ERROR_STOP 1
\if :{?scope}
\else
\set scope app
\endif
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;
\pset format csv
\pset tuples_only on
\pset footer off

\o /out/fp-preserved-tables.csv
select format(
  'select %L as schema_name, %L as table_name, count(*) as row_count, coalesce(md5(string_agg(h, %L order by h)), %L) as table_md5 from (select md5(to_jsonb(t)::text) as h from %I.%I t) s',
  n.nspname, c.relname, ',', 'empty', n.nspname, c.relname)
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where c.relkind in ('r', 'p') and not c.relispartition
  and n.nspname not in ('pg_catalog', 'information_schema', 'supabase_migrations', 'universe', 'geo', 'canon')
  and n.nspname !~ '^pg_'
  and (:'scope' = 'all' or n.nspname not in (
        'auth', 'storage', 'realtime', '_realtime', 'extensions', 'graphql', 'graphql_public', 'vault',
        'pgsodium', 'pgsodium_masks', 'pgbouncer', 'net', 'cron', 'supabase_functions', '_analytics', '_supavisor', 'pgmq'))
order by n.nspname, c.relname
\gexec
\o

\pset tuples_only off
\o /out/fp-rows-shared-worlds.csv
select id, md5(to_jsonb(t)::text) as row_md5 from shared.worlds t order by id;
\o /out/fp-rows-land-candidates.csv
select id, md5(to_jsonb(t)::text) as row_md5 from land.candidates t order by id;
\o /out/fp-rows-shared-activities.csv
select id, md5(to_jsonb(t)::text) as row_md5 from shared.activities t order by id;
\o /out/fp-rows-infrastructure-bases.csv
select id, md5(to_jsonb(t)::text) as row_md5 from infrastructure.bases t order by id;
\o /out/fp-rows-infrastructure-audit.csv
select base_id, md5(to_jsonb(t)::text) as row_md5 from infrastructure.base_legacy_migration_audit t order by base_id;
\o /out/fp-rows-passport-journeys.csv
select id, md5(to_jsonb(t)::text) as row_md5 from passport.journeys t order by id;
\o /out/fp-rows-passport-events.csv
select id, md5(to_jsonb(t)::text) as row_md5 from passport.events t order by id;

-- Privileges of the API roles on the application schemas (V3.2 schemas excluded: they are checked by post-validate).
\o /out/fp-privileges.csv
select r.rolname as role_name, n.nspname as schema_name,
       has_schema_privilege(r.oid, n.oid, 'USAGE') as schema_usage,
       (select count(*) from pg_class c where c.relnamespace = n.oid and c.relkind in ('r','p','v','m')
          and has_table_privilege(r.oid, c.oid, 'SELECT')) as selectable_relations,
       (select count(*) from pg_class c where c.relnamespace = n.oid and c.relkind in ('r','p')
          and has_table_privilege(r.oid, c.oid, 'INSERT,UPDATE,DELETE')) as writable_tables
from pg_roles r cross join pg_namespace n
where r.rolname in ('anon', 'authenticated', 'service_role')
  and n.nspname in ('public', 'shared', 'land', 'passport', 'infrastructure')
order by 1, 2;

-- Reference only (NOT compared: V3.2 intentionally changes it): the universe schema as it was, for rollback.
\o /out/baseline-universe-schema.csv
select 'comment' as item, coalesce(obj_description('universe'::regnamespace, 'pg_namespace'), '<null>') as value
union all
select 'object', c.relkind::text || ':' || c.relname from pg_class c where c.relnamespace = 'universe'::regnamespace
union all
select 'function', p.oid::regprocedure::text from pg_proc p where p.pronamespace = 'universe'::regnamespace
union all
select 'usage:' || r.rolname, has_schema_privilege(r.oid, 'universe'::regnamespace, 'USAGE')::text
from pg_roles r where r.rolname in ('public', 'anon', 'authenticated', 'service_role', 'postgres')
union all
select 'acl', coalesce(n.nspacl::text, '<default>') from pg_namespace n where n.nspname = 'universe'
order by 1, 2;
\o
rollback;
