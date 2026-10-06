-- Bounded cleanup after the Phase 1B audited backfill. No seed or new domain model.
-- One atomic statement: the CLI can execute separate SQL statements independently.
-- lock_timeout applies immediately; statement timeout is enforced by the caller.
do $cleanup$
begin
perform set_config('lock_timeout', '5s', true);

-- Freeze the source, mapping and Passport references through validation and removal.
lock table universe.nodes, universe.frontiers, universe.spots,
  passport.journeys, passport.events,
  infrastructure.bases, infrastructure.base_legacy_migration_audit
  in access exclusive mode;

  if exists (select 1 from universe.nodes where node_type <> 'stay')
     or exists (select 1 from universe.frontiers)
     or exists (select 1 from universe.spots) then
    raise exception 'Legacy cleanup STOP: unexpected nodes/frontiers/spots data';
  end if;
  if exists (select 1 from passport.journeys where node_id is not null)
     or exists (select 1 from passport.events
                where node_id is not null or frontier_id is not null or spot_id is not null) then
    raise exception 'Legacy cleanup STOP: Passport still references legacy objects';
  end if;
  if (select count(*) from infrastructure.base_legacy_migration_audit)
       <> (select count(*) from universe.nodes)
     or exists (
       select 1 from universe.nodes n
       left join infrastructure.base_legacy_migration_audit a
         on a.source_table = 'universe.nodes' and a.source_id = n.id
       left join infrastructure.bases b on b.id = a.base_id
       where a.source_id is null or b.id is null
          or a.source_snapshot is distinct from to_jsonb(n)
          or b.world_id is distinct from n.world_id
          or b.asset_id is distinct from n.asset_id
          or b.name is distinct from n.name
          or b.status is distinct from n.status
          or b.metadata is distinct from n.metadata
          or b.created_at is distinct from n.created_at
          or b.updated_at is distinct from n.updated_at
     ) then
    raise exception 'Legacy cleanup STOP: Base/audit parity failure';
  end if;

-- Drop only empty legacy reference columns, including their own indexes/FKs.
-- RESTRICT deliberately rejects any additional database dependencies.
alter table passport.journeys drop column node_id restrict;
alter table passport.events drop column node_id restrict,
  drop column frontier_id restrict, drop column spot_id restrict;
drop table universe.spots restrict;
drop table universe.frontiers restrict;
drop table universe.nodes restrict;

-- universe.set_updated_at is retained: Passport's existing trigger still uses it.
comment on schema universe is 'Legacy OUTLAND V0 tables retired; set_updated_at remains for Passport. Not a Universe registry.';
comment on table passport.events is 'Append-oriented World journey events. Legacy node/frontier/spot references retired; no new gameplay model introduced.';

end $cleanup$;
