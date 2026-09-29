create schema if not exists universe;
create schema if not exists passport;

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

create table if not exists passport.journeys (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references shared.profiles(id) on update cascade on delete restrict,
  world_id uuid not null references shared.worlds(id) on update cascade on delete restrict,
  node_id uuid null references universe.nodes(id) on update cascade on delete set null,
  started_at timestamptz not null default now(),
  completed_at timestamptz null,
  status text not null default 'active' check (status in ('active','completed','abandoned')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint passport_journeys_time_order check (completed_at is null or completed_at >= started_at)
);

create table if not exists passport.events (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references shared.profiles(id) on update cascade on delete restrict,
  journey_id uuid null references passport.journeys(id) on update cascade on delete set null,
  world_id uuid null references shared.worlds(id) on update cascade on delete set null,
  node_id uuid null references universe.nodes(id) on update cascade on delete set null,
  frontier_id uuid null references universe.frontiers(id) on update cascade on delete set null,
  spot_id uuid null references universe.spots(id) on update cascade on delete set null,
  event_type text not null,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint passport_events_event_type_nonblank check (btrim(event_type) <> '')
);

create index if not exists universe_nodes_world_idx on universe.nodes(world_id);
create index if not exists universe_nodes_asset_idx on universe.nodes(asset_id) where asset_id is not null;
create index if not exists universe_frontiers_node_idx on universe.frontiers(node_id);
create index if not exists universe_spots_frontier_idx on universe.spots(frontier_id);
create index if not exists universe_spots_type_idx on universe.spots(spot_type);
create index if not exists passport_journeys_profile_started_idx on passport.journeys(profile_id, started_at desc);
create index if not exists passport_journeys_world_idx on passport.journeys(world_id);
create index if not exists passport_journeys_node_idx on passport.journeys(node_id) where node_id is not null;
create index if not exists passport_events_profile_time_idx on passport.events(profile_id, occurred_at desc);
create index if not exists passport_events_journey_time_idx on passport.events(journey_id, occurred_at) where journey_id is not null;
create index if not exists passport_events_world_idx on passport.events(world_id) where world_id is not null;
create index if not exists passport_events_node_idx on passport.events(node_id) where node_id is not null;
create index if not exists passport_events_frontier_idx on passport.events(frontier_id) where frontier_id is not null;
create index if not exists passport_events_spot_idx on passport.events(spot_id) where spot_id is not null;
create index if not exists passport_events_type_idx on passport.events(event_type);

create or replace function universe.set_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger universe_nodes_set_updated_at
before update on universe.nodes
for each row execute function universe.set_updated_at();

create trigger universe_frontiers_set_updated_at
before update on universe.frontiers
for each row execute function universe.set_updated_at();

create trigger universe_spots_set_updated_at
before update on universe.spots
for each row execute function universe.set_updated_at();

create trigger passport_journeys_set_updated_at
before update on passport.journeys
for each row execute function universe.set_updated_at();

alter table universe.nodes enable row level security;
alter table universe.frontiers enable row level security;
alter table universe.spots enable row level security;
alter table passport.journeys enable row level security;
alter table passport.events enable row level security;

revoke all on schema universe from public, anon, authenticated;
revoke all on schema passport from public, anon, authenticated;
revoke all on all tables in schema universe from public, anon, authenticated;
revoke all on all tables in schema passport from public, anon, authenticated;
revoke all on all sequences in schema universe from public, anon, authenticated;
revoke all on all sequences in schema passport from public, anon, authenticated;

comment on schema universe is 'OUTLAND Universe structural domain: Nodes, Frontiers and Spots. Portal is represented as a Spot type.';
comment on schema passport is 'OUTLAND Passport journey continuity domain. V0 stores journeys and append-only journey events; credential/card tables are intentionally deferred.';
comment on table universe.nodes is 'Physical OUTLAND Nodes within a World.';
comment on table universe.frontiers is 'Explorable territories associated with a Node.';
comment on table universe.spots is 'Specific discoverable points within a Frontier; portals are spots with spot_type=portal.';
comment on table passport.journeys is 'A person-profile journey through a World; separate from booking truth.';
comment on table passport.events is 'Append-oriented journey events such as NODE_ENTERED, SPOT_DISCOVERED or PORTAL_CROSSED.';
