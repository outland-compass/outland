-- SIDEWORLD Schema V3.2 — Migration 2
-- File: 202610060002_sideworld_geo_foundation.sql
-- STATUS: IMPLEMENTATION MIGRATION.
-- Validated locally; not yet deployed to staging or production.
-- Purpose: add reusable real-world city/location/fact/source knowledge.

begin;

create schema if not exists geo;

comment on schema geo is
  'SIDEWORLD real-world geography, verified location knowledge and provenance.';

create table geo.countries (
  code char(2) primary key,
  name text not null,
  default_locale text,
  metadata jsonb not null default '{}'::jsonb,
  constraint geo_countries_code_upper check (code = upper(code)),
  constraint geo_countries_name_not_blank check (btrim(name) <> '')
);

create table geo.cities (
  id uuid primary key default gen_random_uuid(),
  country_code char(2) not null
    references geo.countries(code) on delete restrict,
  slug text not null,
  name text not null,
  region text,
  timezone text not null,
  default_locale text not null,
  latitude numeric,
  longitude numeric,
  status text not null default 'draft'
    check (status in ('draft','active','archived')),
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','partially_verified','verified','disputed')),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint geo_cities_slug_not_blank check (btrim(slug) <> ''),
  constraint geo_cities_name_not_blank check (btrim(name) <> ''),
  constraint geo_cities_timezone_not_blank check (btrim(timezone) <> ''),
  constraint geo_cities_default_locale_not_blank check (btrim(default_locale) <> ''),
  constraint geo_cities_latitude_range check (latitude is null or latitude between -90 and 90),
  constraint geo_cities_longitude_range check (longitude is null or longitude between -180 and 180),
  constraint geo_cities_country_slug_unique unique (country_code, slug)
);

create table geo.locations (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null
    references geo.cities(id) on delete restrict,
  slug text not null,
  name text not null,
  location_type text not null default 'poi',
  latitude numeric not null,
  longitude numeric not null,
  address_text text,
  public_access boolean,
  accessibility_profile jsonb not null default '{}'::jsonb,
  safety_profile jsonb not null default '{}'::jsonb,
  opening_hours jsonb not null default '{}'::jsonb,
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','partially_verified','verified','disputed')),
  field_verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint geo_locations_slug_not_blank check (btrim(slug) <> ''),
  constraint geo_locations_name_not_blank check (btrim(name) <> ''),
  constraint geo_locations_type_not_blank check (btrim(location_type) <> ''),
  constraint geo_locations_latitude_range check (latitude between -90 and 90),
  constraint geo_locations_longitude_range check (longitude between -180 and 180),
  constraint geo_locations_city_slug_unique unique (city_id, slug)
);

create table geo.location_facts (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null
    references geo.cities(id) on delete restrict,
  location_id uuid
    references geo.locations(id) on delete restrict,
  fact_key text not null,
  statement text not null,
  fact_type text not null default 'general',
  verification_status text not null default 'unverified'
    check (verification_status in ('unverified','partially_verified','verified','disputed')),
  confidence numeric,
  valid_from timestamptz,
  valid_to timestamptz,
  last_verified_at timestamptz,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint geo_location_facts_key_not_blank check (btrim(fact_key) <> ''),
  constraint geo_location_facts_statement_not_blank check (btrim(statement) <> ''),
  constraint geo_location_facts_type_not_blank check (btrim(fact_type) <> ''),
  constraint geo_location_facts_confidence_range
    check (confidence is null or confidence between 0 and 1),
  constraint geo_location_facts_valid_range
    check (valid_to is null or valid_from is null or valid_to >= valid_from),
  constraint geo_location_facts_city_key_unique unique (city_id, fact_key)
);

create table geo.sources (
  id uuid primary key default gen_random_uuid(),
  url text,
  publisher text,
  title text not null,
  source_type text not null,
  published_at timestamptz,
  retrieved_at timestamptz not null default now(),
  trust_tier text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint geo_sources_title_not_blank check (btrim(title) <> ''),
  constraint geo_sources_type_not_blank check (btrim(source_type) <> '')
);

create table geo.fact_sources (
  fact_id uuid not null
    references geo.location_facts(id) on delete cascade,
  source_id uuid not null
    references geo.sources(id) on delete restrict,
  support_type text not null default 'supports'
    check (support_type in ('supports','contradicts','context')),
  note text,
  created_at timestamptz not null default now(),
  primary key (fact_id, source_id)
);

create index geo_cities_country_idx on geo.cities(country_code);
create index geo_locations_city_idx on geo.locations(city_id);
create index geo_location_facts_city_idx on geo.location_facts(city_id);
create index geo_location_facts_location_idx on geo.location_facts(location_id);
create index geo_location_facts_verification_idx on geo.location_facts(verification_status);
create index geo_fact_sources_source_idx on geo.fact_sources(source_id);

create trigger geo_cities_set_updated_at
before update on geo.cities
for each row execute function public.set_updated_at();

create trigger geo_locations_set_updated_at
before update on geo.locations
for each row execute function public.set_updated_at();

create trigger geo_location_facts_set_updated_at
before update on geo.location_facts
for each row execute function public.set_updated_at();

alter table geo.countries enable row level security;
alter table geo.cities enable row level security;
alter table geo.locations enable row level security;
alter table geo.location_facts enable row level security;
alter table geo.sources enable row level security;
alter table geo.fact_sources enable row level security;

revoke all on schema geo from public, anon, authenticated, service_role;
revoke all on all tables in schema geo from public, anon, authenticated, service_role;

commit;
