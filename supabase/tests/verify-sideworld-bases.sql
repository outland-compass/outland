-- Run only on isolated DB after replaying all migrations.
do $$
begin
 if to_regclass('infrastructure.bases') is null then
  raise exception 'Missing infrastructure.bases';
 end if;
 if to_regclass('infrastructure.base_legacy_migration_audit') is null then
  raise exception 'Missing base migration audit';
 end if;
 if (select count(*) from infrastructure.base_legacy_migration_audit) <> (select count(*) from universe.nodes where node_type='stay') then
  raise exception 'Legacy stay/audit count mismatch';
 end if;
 if exists (
  select 1 from infrastructure.base_legacy_migration_audit a
  join universe.nodes n on a.source_id=n.id and a.source_table='universe.nodes'
  join infrastructure.bases b on b.id=a.base_id
  where b.world_id is distinct from n.world_id
     or b.asset_id is distinct from n.asset_id
     or b.name is distinct from n.name
     or b.status is distinct from n.status
     or b.metadata is distinct from n.metadata
     or b.created_at is distinct from n.created_at
     or b.updated_at is distinct from n.updated_at
     or a.source_snapshot is distinct from to_jsonb(n)
 ) then
  raise exception 'Legacy/base data parity failure';
 end if;
 if exists (
  select 1 from pg_class c join pg_namespace ns on ns.oid=c.relnamespace
  where ns.nspname='infrastructure' and c.relname in ('bases','base_legacy_migration_audit') and not c.relrowsecurity
 ) then
  raise exception 'Infrastructure RLS disabled';
 end if;
end $$;
