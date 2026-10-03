-- Read-only inventory of staging. Every statement runs inside a READ ONLY transaction.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;
\copy (select now() as captured_at, current_setting('server_version') as server_version, current_user as db_user, current_setting('transaction_read_only') as tx_read_only) to '/out/inventory-meta.csv' csv header
\copy (select version, name from supabase_migrations.schema_migrations order by version) to '/out/inventory-migrations.csv' csv header
-- Exact row counts for every user table (generic, so restore fidelity can be checked table by table).
\copy (select n.nspname as schema, c.relname as table, (xpath('/row/n/text()', query_to_xml(format('select count(*) as n from %I.%I', n.nspname, c.relname), false, true, '')))[1]::text::bigint as n from pg_class c join pg_namespace n on n.oid = c.relnamespace where c.relkind in ('r','p') and n.nspname in ('public','shared','land','universe','passport','storage','auth','supabase_migrations') order by 1, 2) to '/out/inventory-counts.csv' csv header
\copy (select w.id, w.code, md5(to_jsonb(w)::text) row_md5, to_jsonb(w) row_json from shared.worlds w order by w.id) to '/out/inventory-worlds.csv' csv header
\copy (select c.id, c.world_id, w.code world_code, md5(to_jsonb(c)::text) row_md5, to_jsonb(c) row_json from land.candidates c left join shared.worlds w on w.id = c.world_id order by c.id) to '/out/inventory-candidates.csv' csv header
\copy (select nspname from pg_namespace order by 1) to '/out/inventory-schemas.csv' csv header
rollback;
