-- SIDEWORLD V3.2: deterministic structural fingerprint of the universe/geo/canon objects. READ ONLY.
-- Included (\ir) by post-validate.sql and committed-state-check.sql INSIDE their read-only transaction.
-- Sets the psql variables :v32_structure_md5 and :v32_structure_items. Independent of search_path (pinned to
-- pg_catalog for this transaction, so every name is schema-qualified) and of OIDs. Privileges/ACLs are NOT part
-- of the fingerprint (hosted defaults may differ); they are checked semantically by the callers.
-- Covered: schemas + comments, tables + comments + RLS flags, columns (type, nullability, default), constraints
-- (definition), indexes (definition), triggers (definition), functions in the three schemas.
set local search_path = pg_catalog;
with rel as (
  select c.oid, n.nspname, c.relname, c.relkind, c.relrowsecurity, c.relforcerowsecurity
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname in ('universe', 'geo', 'canon') and c.relkind in ('r', 'p', 'v', 'm', 'f', 'S')
), items as (
  select 'schema|' || n.nspname || '|' || coalesce(obj_description(n.oid, 'pg_namespace'), '') as item
  from pg_namespace n where n.nspname in ('universe', 'geo', 'canon')
  union all
  select 'relation|' || nspname || '.' || relname || '|' || relkind || '|rls=' || relrowsecurity || '|force=' || relforcerowsecurity
         || '|' || coalesce(obj_description(oid, 'pg_class'), '') from rel
  union all
  select 'column|' || r.nspname || '.' || r.relname || '|' || a.attnum || '|' || a.attname || '|' || format_type(a.atttypid, a.atttypmod)
         || '|notnull=' || a.attnotnull || '|default=' || coalesce(pg_get_expr(d.adbin, d.adrelid), '')
  from rel r join pg_attribute a on a.attrelid = r.oid and a.attnum > 0 and not a.attisdropped
  left join pg_attrdef d on d.adrelid = a.attrelid and d.adnum = a.attnum
  union all
  select 'constraint|' || r.nspname || '.' || r.relname || '|' || co.conname || '|' || co.contype || '|' || pg_get_constraintdef(co.oid, true)
  from rel r join pg_constraint co on co.conrelid = r.oid
  union all
  select 'index|' || r.nspname || '.' || r.relname || '|' || pg_get_indexdef(i.indexrelid)
  from rel r join pg_index i on i.indrelid = r.oid
  union all
  select 'trigger|' || r.nspname || '.' || r.relname || '|' || pg_get_triggerdef(t.oid, true)
  from rel r join pg_trigger t on t.tgrelid = r.oid and not t.tgisinternal
  union all
  select 'function|' || p.oid::regprocedure::text
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname in ('universe', 'geo', 'canon')
)
select md5(string_agg(item, E'\n' order by item)) as v32_structure_md5, count(*) as v32_structure_items from items \gset
