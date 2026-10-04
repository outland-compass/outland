-- Run only after separate recovery approval, in one transaction: psql -1 -v ON_ERROR_STOP=1.
-- Recreates exactly the retired structures; preserves Base/audit and Passport rows.
set local lock_timeout='5s';
set local statement_timeout='60s';
lock table infrastructure.bases, infrastructure.base_legacy_migration_audit,
  passport.journeys, passport.events in access exclusive mode;
do $$ begin
 if to_regclass('universe.nodes') is not null
    or to_regclass('universe.frontiers') is not null
    or to_regclass('universe.spots') is not null then
  raise exception 'Recovery STOP: legacy tables already exist';
 end if;
end $$;
create table if not exists universe.nodes (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references shared.worlds(id) on update cascade on delete restrict,
  asset_id uuid null references shared.assets(id) on update cascade on delete set null,
  code text not null,
  name text not null,
  node_type text not null default 'stay',
  status text not null default 'planned' check (status in ('planned','active','retired')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint universe_nodes_world_code_unique unique (world_id, code),
  constraint universe_nodes_code_nonblank check (btrim(code) <> ''),
  constraint universe_nodes_name_nonblank check (btrim(name) <> '')
);

create table if not exists universe.frontiers (
  id uuid primary key default gen_random_uuid(),
  node_id uuid not null references universe.nodes(id) on update cascade on delete cascade,
  code text not null,
  name text not null,
  description text null,
  status text not null default 'planned' check (status in ('planned','active','retired')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint universe_frontiers_node_code_unique unique (node_id, code),
  constraint universe_frontiers_code_nonblank check (btrim(code) <> ''),
  constraint universe_frontiers_name_nonblank check (btrim(name) <> '')
);

create table if not exists universe.spots (
  id uuid primary key default gen_random_uuid(),
  frontier_id uuid not null references universe.frontiers(id) on update cascade on delete cascade,
  code text not null,
  name text not null,
  spot_type text not null default 'ordinary' check (spot_type in ('ordinary','checkpoint','portal')),
  latitude numeric(9,6) null check (latitude is null or latitude between -90 and 90),
  longitude numeric(9,6) null check (longitude is null or longitude between -180 and 180),
  discovery_mode text null,
  status text not null default 'planned' check (status in ('planned','active','retired')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint universe_spots_frontier_code_unique unique (frontier_id, code),
  constraint universe_spots_code_nonblank check (btrim(code) <> ''),
  constraint universe_spots_name_nonblank check (btrim(name) <> '')
);


insert into universe.nodes
select (jsonb_populate_record(null::universe.nodes,a.source_snapshot)).*
from infrastructure.base_legacy_migration_audit a
where a.source_table='universe.nodes';
create index if not exists universe_nodes_world_idx on universe.nodes(world_id);
create index if not exists universe_nodes_asset_idx on universe.nodes(asset_id) where asset_id is not null;
create index if not exists universe_frontiers_node_idx on universe.frontiers(node_id);
create index if not exists universe_spots_frontier_idx on universe.spots(frontier_id);
create index if not exists universe_spots_type_idx on universe.spots(spot_type);
create trigger universe_nodes_set_updated_at
before update on universe.nodes
for each row execute function universe.set_updated_at();

create trigger universe_frontiers_set_updated_at
before update on universe.frontiers
for each row execute function universe.set_updated_at();

create trigger universe_spots_set_updated_at
before update on universe.spots
for each row execute function universe.set_updated_at();


alter table passport.journeys add column node_id uuid references universe.nodes(id) on update cascade on delete set null;
alter table passport.events add column node_id uuid references universe.nodes(id) on update cascade on delete set null,
 add column frontier_id uuid references universe.frontiers(id) on update cascade on delete set null,
 add column spot_id uuid references universe.spots(id) on update cascade on delete set null;
create index passport_journeys_node_idx on passport.journeys(node_id) where node_id is not null;
create index passport_events_node_idx on passport.events(node_id) where node_id is not null;
create index passport_events_frontier_idx on passport.events(frontier_id) where frontier_id is not null;
create index passport_events_spot_idx on passport.events(spot_id) where spot_id is not null;
alter table universe.nodes enable row level security;
alter table universe.frontiers enable row level security;
alter table universe.spots enable row level security;
revoke all on schema universe from public, anon, authenticated;
revoke all on all tables in schema universe from public, anon, authenticated;
comment on schema universe is 'OUTLAND Universe structural domain: Nodes, Frontiers and Spots. Portal is represented as a Spot type.';
comment on table universe.nodes is 'Physical OUTLAND Nodes within a World.';
comment on table universe.frontiers is 'Explorable territories associated with a Node.';
comment on table universe.spots is 'Specific discoverable points within a Frontier; portals are spots with spot_type=portal.';
comment on table passport.events is 'Append-oriented journey events such as NODE_ENTERED, SPOT_DISCOVERED or PORTAL_CROSSED.';
do $$ begin
 if exists (select 1 from infrastructure.base_legacy_migration_audit a
            left join universe.nodes n on n.id=a.source_id
            where a.source_table <> 'universe.nodes'
               or a.source_snapshot is distinct from to_jsonb(n)) then
  raise exception 'Recovery STOP: source snapshot mismatch';
 end if;
end $$;
