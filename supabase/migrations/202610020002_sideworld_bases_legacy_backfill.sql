-- Additive audited backfill. No changes to legacy Universe or Passport.
create table infrastructure.base_legacy_migration_audit (
 source_table text not null,
 source_id uuid not null,
 base_id uuid not null unique references infrastructure.bases(id),
 source_snapshot jsonb not null,
 migrated_at timestamptz not null default now(),
 primary key (source_table, source_id)
);
alter table infrastructure.base_legacy_migration_audit enable row level security;
revoke all on infrastructure.base_legacy_migration_audit from public, anon, authenticated;

do $$
declare old_record universe.nodes%rowtype;
declare new_id uuid;
begin
 if exists (select 1 from universe.nodes where node_type <> 'stay') then
  raise exception 'Unexpected legacy node type: manual review required';
 end if;
 if exists (select 1 from universe.frontiers) or exists (select 1 from universe.spots) then
  raise exception 'Nonempty legacy frontier/spot tables: manual review required';
 end if;
 for old_record in select * from universe.nodes loop
  new_id := gen_random_uuid();
  insert into infrastructure.bases(id,world_id,asset_id,name,status,metadata,created_at,updated_at)
   values(new_id,old_record.world_id,old_record.asset_id,old_record.name,old_record.status,old_record.metadata,old_record.created_at,old_record.updated_at);
  insert into infrastructure.base_legacy_migration_audit(source_table,source_id,base_id,source_snapshot)
   values('universe.nodes',old_record.id,new_id,to_jsonb(old_record));
 end loop;
 if (select count(*) from infrastructure.base_legacy_migration_audit) <> (select count(*) from universe.nodes) then
  raise exception 'Backfill row count mismatch';
 end if;
end $$;
