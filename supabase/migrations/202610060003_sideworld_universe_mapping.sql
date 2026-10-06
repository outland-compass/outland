-- SIDEWORLD Schema V3.2 — Migration 3
-- File: 202610060003_sideworld_universe_mapping.sql
-- STATUS: IMPLEMENTATION MIGRATION.
-- Validated locally; not yet deployed to staging or production.
-- Purpose: map canonical SIDEWORLD Worlds to cities and optionally to OUTLAND
--          operational Worlds without repurposing shared.worlds.


create table universe.world_cities (
  world_id uuid not null
    references universe.worlds(id) on delete cascade,
  city_id uuid not null
    references geo.cities(id) on delete restrict,
  relationship_type text not null default 'primary'
    check (relationship_type in ('primary','story','operational','expansion')),
  created_at timestamptz not null default now(),
  primary key (world_id, city_id)
);

create table universe.world_outland_map (
  world_id uuid primary key
    references universe.worlds(id) on delete cascade,
  outland_world_id uuid not null unique
    references shared.worlds(id) on delete restrict,
  relationship_type text not null default 'operational'
    check (relationship_type in ('operational')),
  created_at timestamptz not null default now()
);

create index universe_world_cities_city_idx
  on universe.world_cities(city_id);

alter table universe.world_cities enable row level security;
alter table universe.world_outland_map enable row level security;

revoke all on universe.world_cities, universe.world_outland_map
  from public, anon, authenticated, service_role;

comment on table universe.world_cities is
  'Many-to-many mapping between canonical SIDEWORLD Worlds and real cities.';
comment on table universe.world_outland_map is
  'Optional explicit 1:1 bridge from a SIDEWORLD canonical World to an OUTLAND operational shared.worlds row.';

-- Intentionally no automatic backfill or seed in this migration.
-- Existing shared.worlds rows must not be promoted to SIDEWORLD Worlds implicitly.

