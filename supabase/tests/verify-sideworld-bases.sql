-- Execute on an isolated database AFTER clean migration replay.
-- Read-only assertions after legacy cleanup; Passport remains.
begin;
do $$
begin
 if to_regclass('infrastructure.bases') is null
    or to_regclass('infrastructure.base_legacy_migration_audit') is null then
  raise exception 'SIDEWORLD Base tables missing';
 end if;
 -- Audit provenance survives source retirement; clean-install seed Bases need no
 -- historical audit. Every actual backfill audit must retain exact mapped values.
 if exists (
   select 1 from infrastructure.base_legacy_migration_audit a
   left join infrastructure.bases b on b.id=a.base_id
   where a.source_table <> 'universe.nodes' or b.id is null
      or a.source_id::text is distinct from a.source_snapshot->>'id'
      or a.source_snapshot->>'node_type' is distinct from 'stay'
      or b.world_id::text is distinct from a.source_snapshot->>'world_id'
      or b.asset_id::text is distinct from a.source_snapshot->>'asset_id'
      or b.name is distinct from a.source_snapshot->>'name'
      or b.status is distinct from a.source_snapshot->>'status'
      or b.metadata is distinct from a.source_snapshot->'metadata'
      or b.created_at is distinct from (a.source_snapshot->>'created_at')::timestamptz
      or b.updated_at is distinct from (a.source_snapshot->>'updated_at')::timestamptz
 ) then
   raise exception 'Base/audit snapshot parity failure';
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
 if to_regclass('universe.nodes') is not null
    or to_regclass('universe.frontiers') is not null
    or to_regclass('universe.spots') is not null then
   raise exception 'Legacy Universe tables remain';
 end if;
 if to_regclass('passport.journeys') is null
    or to_regclass('passport.events') is null then
   raise exception 'Passport tables missing';
 end if;
 if exists (select 1 from information_schema.columns
            where table_schema='passport'
              and table_name in ('journeys','events')
              and column_name in ('node_id','frontier_id','spot_id')) then
   raise exception 'Legacy Passport columns remain';
 end if;
end $$;
rollback;
