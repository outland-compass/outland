-- SIDEWORLD Schema V3.2 — Migration 1
-- File: 202610060001_sideworld_universe_foundation.sql
-- STATUS: IMPLEMENTATION MIGRATION.
-- Validated locally; not yet deployed to staging or production.
-- Purpose: add canonical SIDEWORLD Universe/World/Theme entities without changing
--          the existing OUTLAND operational shared.worlds registry.

begin;

create schema if not exists universe;

-- The schema already contains universe.set_updated_at(), retained for the
-- existing passport.journeys trigger. This comment updates domain intent
-- without removing that compatibility helper.
comment on schema universe is
  'SIDEWORLD canonical Universe/World domain. Existing set_updated_at helper is retained for Passport compatibility.';

create table universe.universes (
  id uuid primary key default gen_random_uuid(),
  slug text not null,
  name text not null,
  visibility text not null default 'private'
    check (visibility in ('private','unlisted','public')),
  status text not null default 'draft'
    check (status in ('draft','active','archived')),
  description text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint universe_universes_slug_not_blank check (btrim(slug) <> ''),
  constraint universe_universes_name_not_blank check (btrim(name) <> ''),
  constraint universe_universes_slug_unique unique (slug)
);

create table universe.worlds (
  id uuid primary key default gen_random_uuid(),
  universe_id uuid not null
    references universe.universes(id) on delete restrict,
  slug text not null,
  name text not null,
  status text not null default 'draft'
    check (status in ('draft','active','archived')),
  summary text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint universe_worlds_slug_not_blank check (btrim(slug) <> ''),
  constraint universe_worlds_name_not_blank check (btrim(name) <> ''),
  constraint universe_worlds_universe_slug_unique unique (universe_id, slug)
);

create table universe.themes (
  id uuid primary key default gen_random_uuid(),
  universe_id uuid
    references universe.universes(id) on delete restrict,
  slug text not null,
  name text not null,
  description text,
  status text not null default 'draft'
    check (status in ('draft','active','archived')),
  style_profile jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint universe_themes_slug_not_blank check (btrim(slug) <> ''),
  constraint universe_themes_name_not_blank check (btrim(name) <> '')
);

create unique index universe_themes_global_slug_uq
  on universe.themes(slug)
  where universe_id is null;

create unique index universe_themes_scoped_slug_uq
  on universe.themes(universe_id, slug)
  where universe_id is not null;

create index universe_worlds_universe_idx
  on universe.worlds(universe_id);

create index universe_worlds_status_idx
  on universe.worlds(status);

create index universe_themes_universe_idx
  on universe.themes(universe_id);

create trigger universe_universes_set_updated_at
before update on universe.universes
for each row execute function public.set_updated_at();

create trigger universe_worlds_set_updated_at
before update on universe.worlds
for each row execute function public.set_updated_at();

create trigger universe_themes_set_updated_at
before update on universe.themes
for each row execute function public.set_updated_at();

alter table universe.universes enable row level security;
alter table universe.worlds enable row level security;
alter table universe.themes enable row level security;

-- Foundation tables remain private. Studio/API exposure is a later, separately
-- reviewed change.
revoke all on schema universe from public, anon, authenticated, service_role;
revoke all on universe.universes, universe.worlds, universe.themes
  from public, anon, authenticated, service_role;

comment on table universe.universes is
  'Canonical SIDEWORLD Universe registry. SIDEWORLD itself is the platform, not a row here.';
comment on table universe.worlds is
  'Canonical SIDEWORLD World registry. Distinct from OUTLAND operational shared.worlds.';
comment on table universe.themes is
  'Reusable SIDEWORLD creative/gameplay theme identity; not a substitute for canon.franchises.';

commit;
