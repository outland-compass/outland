-- SIDEWORLD Schema V3.2 — Migration 4
-- File: 202610060004_sideworld_canon_foundation.sql
-- STATUS: IMPLEMENTATION MIGRATION.
-- Validated locally; not yet deployed to staging or production.
-- Purpose: add structured cross-media fictional canon for SIDEWORLD Studio.

begin;

create schema if not exists canon;

comment on schema canon is
  'SIDEWORLD fictional IP canon: franchises, series, characters, factions, lore and AI continuity constraints.';

create table canon.franchises (
  id uuid primary key default gen_random_uuid(),
  universe_id uuid not null
    references universe.universes(id) on delete restrict,
  slug text not null,
  name text not null,
  description text,
  status text not null default 'draft'
    check (status in ('draft','active','archived')),
  canon_version integer not null default 1
    check (canon_version > 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint canon_franchises_slug_not_blank check (btrim(slug) <> ''),
  constraint canon_franchises_name_not_blank check (btrim(name) <> ''),
  constraint canon_franchises_universe_slug_unique unique (universe_id, slug)
);

create table canon.series (
  id uuid primary key default gen_random_uuid(),
  franchise_id uuid not null
    references canon.franchises(id) on delete restrict,
  theme_id uuid
    references universe.themes(id) on delete restrict,
  slug text not null,
  name text not null,
  premise text,
  status text not null default 'draft'
    check (status in ('draft','active','archived')),
  sort_order integer not null default 100,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint canon_series_slug_not_blank check (btrim(slug) <> ''),
  constraint canon_series_name_not_blank check (btrim(name) <> ''),
  constraint canon_series_sort_order_positive check (sort_order > 0),
  constraint canon_series_franchise_slug_unique unique (franchise_id, slug)
);

create table canon.characters (
  id uuid primary key default gen_random_uuid(),
  franchise_id uuid not null
    references canon.franchises(id) on delete restrict,
  slug text not null,
  name text not null,
  display_name text,
  role text,
  age integer,
  bio text,
  canon_status text not null default 'draft'
    check (canon_status in ('draft','proposed','approved','retired')),
  identity_profile jsonb not null default '{}'::jsonb,
  personality_profile jsonb not null default '{}'::jsonb,
  knowledge_profile jsonb not null default '{}'::jsonb,
  voice_profile jsonb not null default '{}'::jsonb,
  visual_profile jsonb not null default '{}'::jsonb,
  ai_rules jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint canon_characters_slug_not_blank check (btrim(slug) <> ''),
  constraint canon_characters_name_not_blank check (btrim(name) <> ''),
  constraint canon_characters_age_positive check (age is null or age > 0),
  constraint canon_characters_franchise_slug_unique unique (franchise_id, slug)
);

create table canon.character_relationships (
  id uuid primary key default gen_random_uuid(),
  franchise_id uuid not null
    references canon.franchises(id) on delete restrict,
  character_a_id uuid not null
    references canon.characters(id) on delete restrict,
  character_b_id uuid not null
    references canon.characters(id) on delete restrict,
  relationship_type text not null,
  description text,
  canon_status text not null default 'draft'
    check (canon_status in ('draft','proposed','approved','retired')),
  valid_from_phase text,
  valid_to_phase text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint canon_character_relationship_type_not_blank
    check (btrim(relationship_type) <> ''),
  constraint canon_character_relationship_not_self
    check (character_a_id <> character_b_id)
);

create table canon.factions (
  id uuid primary key default gen_random_uuid(),
  franchise_id uuid not null
    references canon.franchises(id) on delete restrict,
  slug text not null,
  name text not null,
  faction_type text,
  description text,
  visibility text not null default 'hidden'
    check (visibility in ('hidden','partial','public')),
  canon_status text not null default 'draft'
    check (canon_status in ('draft','proposed','approved','retired')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint canon_factions_slug_not_blank check (btrim(slug) <> ''),
  constraint canon_factions_name_not_blank check (btrim(name) <> ''),
  constraint canon_factions_franchise_slug_unique unique (franchise_id, slug)
);

create table canon.lore_facts (
  id uuid primary key default gen_random_uuid(),
  franchise_id uuid not null
    references canon.franchises(id) on delete restrict,
  series_id uuid
    references canon.series(id) on delete restrict,
  fact_key text not null,
  statement text not null,
  canon_status text not null default 'draft'
    check (canon_status in ('draft','proposed','approved','retired')),
  reveal_phase text,
  visibility text not null default 'internal'
    check (visibility in ('internal','hidden','player_known','public')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint canon_lore_facts_key_not_blank check (btrim(fact_key) <> ''),
  constraint canon_lore_facts_statement_not_blank check (btrim(statement) <> ''),
  constraint canon_lore_facts_franchise_key_unique unique (franchise_id, fact_key)
);

create table canon.canon_rules (
  id uuid primary key default gen_random_uuid(),
  franchise_id uuid not null
    references canon.franchises(id) on delete restrict,
  series_id uuid
    references canon.series(id) on delete restrict,
  character_id uuid
    references canon.characters(id) on delete restrict,
  rule_type text not null,
  rule_text text not null,
  severity text not null default 'error'
    check (severity in ('info','warning','error')),
  status text not null default 'active'
    check (status in ('draft','active','retired')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint canon_rules_type_not_blank check (btrim(rule_type) <> ''),
  constraint canon_rules_text_not_blank check (btrim(rule_text) <> '')
);

create index canon_franchises_universe_idx on canon.franchises(universe_id);
create index canon_series_franchise_idx on canon.series(franchise_id);
create index canon_series_theme_idx on canon.series(theme_id);
create index canon_characters_franchise_idx on canon.characters(franchise_id);
create index canon_character_relationships_a_idx on canon.character_relationships(character_a_id);
create index canon_character_relationships_b_idx on canon.character_relationships(character_b_id);
create index canon_factions_franchise_idx on canon.factions(franchise_id);
create index canon_lore_facts_series_idx on canon.lore_facts(series_id);
create index canon_canon_rules_character_idx on canon.canon_rules(character_id);

create trigger canon_franchises_set_updated_at
before update on canon.franchises
for each row execute function public.set_updated_at();

create trigger canon_series_set_updated_at
before update on canon.series
for each row execute function public.set_updated_at();

create trigger canon_characters_set_updated_at
before update on canon.characters
for each row execute function public.set_updated_at();

create trigger canon_character_relationships_set_updated_at
before update on canon.character_relationships
for each row execute function public.set_updated_at();

create trigger canon_factions_set_updated_at
before update on canon.factions
for each row execute function public.set_updated_at();

create trigger canon_lore_facts_set_updated_at
before update on canon.lore_facts
for each row execute function public.set_updated_at();

create trigger canon_canon_rules_set_updated_at
before update on canon.canon_rules
for each row execute function public.set_updated_at();

alter table canon.franchises enable row level security;
alter table canon.series enable row level security;
alter table canon.characters enable row level security;
alter table canon.character_relationships enable row level security;
alter table canon.factions enable row level security;
alter table canon.lore_facts enable row level security;
alter table canon.canon_rules enable row level security;

revoke all on schema canon from public, anon, authenticated, service_role;
revoke all on all tables in schema canon from public, anon, authenticated, service_role;

commit;
