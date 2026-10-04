-- Execute on an isolated database AFTER clean migration replay.
-- Read-only assertions; legacy Universe and Passport must still exist.
begin;
do $$
declare
 expected_count bigint;
begin
 if to_regclass('infrastructure.bases') is null
    or to_regclass('infrastructure.base_legacy_migration_audit') is null then
  raise exception 'SIDEWORLD Base tables missing';
 end if;
 select count(*) into expected_count from universe.nodes where node_type='stay';
 if (select count(*) from infrastructure.bases) <> expected_count
    or (select count(*) from infrastructure.base_legacy_migration_audit) <> expected_count then
  raise exception 'Base/audit/stay row counts differ';
 end if;
 if exists (
   select 1 from universe.nodes n
   left join infrastructure.base_legacy_migration_audit a
     on a.source_table='universe.nodes' and a.source_id=n.id
   left join infrastructure.bases b on b.id=a.base_id
   where n.node_type='stay'
     and (a.source_id is null or b.id is null
       or b.world_id is distinct from n.world_id
       or b.asset_id is distinct from n.asset_id
       or b.name is distinct from n.name
       or b.status is distinct from n.status
       or b.metadata is distinct from n.metadata
       or b.created_at is distinct from n.created_at
       or b.updated_at is distinct from n.updated_at
       or a.source_snapshot is distinct from to_jsonb(n))
 ) then
   raise exception 'Missing mapping or Base parity failure';
 end if;
 if exists (
   select 1 from infrastructure.base_legacy_migration_audit a
   left join universe.nodes n on n.id=a.source_id
   where a.source_table <> 'universe.nodes' or n.id is null
 ) then
   raise exception 'Orphaned or unexpected audit provenance';
 end if;
 if (select count(*) from pg_class c join pg_namespace s on s.oid=c.relnamespace
      where s.nspname='infrastructure' and c.relname in ('bases','base_legacy_migration_audit')
      and c.relkind='r' and c.relrowsecurity) <> 2 then
   raise exception 'RLS missing on infrastructure tables';
 end if;
 if has_schema_privilege('anon','infrastructure','USAGE')
    or has_schema_privilege('authenticated','infrastructure','USAGE')
    or has_table_privilege('anon','infrastructure.bases','SELECT')
    or has_table_privilege('authenticated','infrastructure.bases','SELECT') then
   raise exception 'Infrastructure is exposed to public client roles';
 end if;
 if to_regclass('universe.nodes') is null
    or to_regclass('universe.frontiers') is null
    or to_regclass('universe.spots') is null
    or to_regclass('passport.journeys') is null
    or to_regclass('passport.events') is null then
   raise exception 'Legacy dependencies were prematurely removed';
 end if;
end $$;
rollback;
