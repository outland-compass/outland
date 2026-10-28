-- SIDEWORLD Location Intelligence V3 | ADDITIVE PROPOSAL
-- Owner: OUTLAND canonical database repository. No deployment implied by this file.
-- Preserve geo.locations, geo.location_facts, geo.sources, geo.fact_sources and all canon registries.
-- Founder policy: default navigation eligibility; only the full generated quest requires human field QA.

-- Composite reference keys enforce same-city hierarchy and same-franchise series/character uses.
create unique index geo_locations_id_city_v3_uq on geo.locations(id, city_id);
create unique index geo_facts_id_location_v3_uq on geo.location_facts(id, location_id);
create unique index geo_facts_id_city_v3_uq on geo.location_facts(id, city_id);
create unique index canon_series_id_franchise_v3_uq on canon.series(id, franchise_id);
create unique index canon_characters_id_franchise_v3_uq on canon.characters(id, franchise_id);

-- A first-class research intake registry. No GPS required for future discoveries.
-- Source payloads are kept intact and do not compete with canonical geo.locations.
create table geo.location_research_candidates (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references geo.cities(id) on delete restrict,
  source_key text not null check (length(btrim(source_key)) > 0),
  external_research_id text not null check (length(btrim(external_research_id)) > 0),
  location_id uuid,
  source_fact_id uuid unique,
  display_name text not null check (length(btrim(display_name)) > 0),
  raw_v2 jsonb not null default '{}'::jsonb check (jsonb_typeof(raw_v2) = 'object'),
  raw_v3 jsonb not null default '{}'::jsonb check (jsonb_typeof(raw_v3) = 'object'),
  provenance jsonb not null default '{}'::jsonb,
  navigation_eligible boolean not null default true,
  quest_field_qa_required boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint geo_research_unique_external_id_v3 unique (city_id,source_key,external_research_id),
  constraint geo_research_location_city_v3 foreign key (location_id,city_id)
    references geo.locations(id,city_id) on delete restrict,
  constraint geo_research_fact_city_v3 foreign key (source_fact_id,city_id)
    references geo.location_facts(id,city_id) on delete restrict
);
create index geo_research_location_v3_idx on geo.location_research_candidates(location_id);
create index geo_research_city_v3_idx on geo.location_research_candidates(city_id);
comment on table geo.location_research_candidates is
  'Preserved intake dossier; promotion to canonical geo.locations is a link, never a second physical-location identity. No per-location approval.';

-- One physical containment parent per child; multiple independent facts/clues remain allowed.
create table geo.location_hierarchy (
  child_location_id uuid primary key,
  parent_location_id uuid not null,
  city_id uuid not null references geo.cities(id) on delete restrict,
  relationship text not null default 'contained_within'
    check (relationship in ('contained_within','part_of_structure')),
  evidence_fact_id uuid,
  note text,
  created_at timestamptz not null default now(),
  constraint geo_hierarchy_distinct_v3 check (child_location_id <> parent_location_id),
  constraint geo_hierarchy_parent_city_v3 foreign key (parent_location_id,city_id)
    references geo.locations(id,city_id) on delete restrict,
  constraint geo_hierarchy_child_city_v3 foreign key (child_location_id,city_id)
    references geo.locations(id,city_id) on delete restrict,
  constraint geo_hierarchy_evidence_city_v3 foreign key (evidence_fact_id,city_id)
    references geo.location_facts(id,city_id) on delete restrict
);
create index geo_hierarchy_parent_v3_idx on geo.location_hierarchy(parent_location_id);
-- Prevent cyclic tree edges even when written outside Studio.
create function geo.location_hierarchy_prevent_cycle_v3()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if exists (
    with recursive descendants(id) as (
      select child_location_id from geo.location_hierarchy
        where parent_location_id = new.child_location_id
      union
      select h.child_location_id from geo.location_hierarchy h
        join descendants d on h.parent_location_id = d.id
    )
    select 1 from descendants where id = new.parent_location_id
  ) then
    raise exception 'Location hierarchy cycle' using errcode = '23514';
  end if;
  return new;
end $$;
create trigger geo_location_hierarchy_no_cycle_v3
  before insert or update on geo.location_hierarchy
  for each row execute function geo.location_hierarchy_prevent_cycle_v3();

-- Clues = observable physical/evidentiary objects, not collectible items, partners, or bases.
-- A coordinate here is an optional research reference, never an asserted safe arrival pin.
create table geo.location_clues (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references geo.locations(id) on delete restrict,
  source_fact_id uuid,
  source_id uuid references geo.sources(id) on delete restrict,
  clue_key text not null check (length(btrim(clue_key)) > 0),
  title text not null check (length(btrim(title)) > 0),
  clue_kind text not null check (clue_kind in (
    'inscription','architectural_detail','landscape_feature','object','viewpoint',
    'historical_footprint','area_reference','other')),
  description text,
  physical_presence text not null default 'unknown' check (physical_presence in (
    'reported_current','historical_missing','seasonal','variable','unknown')),
  reference_latitude numeric check (reference_latitude between -90 and 90),
  reference_longitude numeric check (reference_longitude between -180 and 180),
  uncertainty_m integer check (uncertainty_m is null or uncertainty_m >= 0),
  source_locator text,
  safe_observation_hint text,
  navigation_eligible boolean not null default true,
  requires_quest_field_qa boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint geo_location_clue_unique_v3 unique (location_id,clue_key),
  constraint geo_location_clue_coordinate_pair_v3 check (
    (reference_latitude is null) = (reference_longitude is null)),
  constraint geo_clue_fact_is_same_location_v3 foreign key (source_fact_id,location_id)
    references geo.location_facts(id,location_id) on delete restrict
);
create index geo_location_clues_fact_v3_idx on geo.location_clues(source_fact_id);
comment on table geo.location_clues is
  'Reusable real-world observable clue, no human per-location approval; physical safety and final pin checked during whole-quest field QA.';

-- The existing fact/source graph remains authoritative for evidence.
-- Optional atomic quote anchors make supports/contradicts/context independently auditable.
alter table geo.fact_sources
  add column source_locator text,
  add column source_excerpt text,
  add column observed_at timestamptz;
comment on column geo.fact_sources.source_excerpt is
  'Short attributed evidence excerpt; rights/reuse restrictions apply. A link marked context is not independently verified support.';

-- Canon overlay, many-to-many. No duplicate universe/franchise/location rows.
create table canon.location_franchise_fits (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references geo.locations(id) on delete restrict,
  franchise_id uuid not null references canon.franchises(id) on delete restrict,
  series_id uuid,
  source_fact_id uuid,
  status text not null default 'hypothesis'
    check (status in ('hypothesis','canon_aligned','retired')),
  narrative_hook text,
  motif_tags text[] not null default array[]::text[],
  gameplay_hints jsonb not null default '{}'::jsonb,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint canon_location_fit_series_franchise_v3 foreign key (series_id,franchise_id)
    references canon.series(id,franchise_id) on delete restrict,
  constraint canon_location_fit_fact_location_v3 foreign key (source_fact_id,location_id)
    references geo.location_facts(id,location_id) on delete restrict
);
create unique index canon_location_fit_unscoped_v3_uq
  on canon.location_franchise_fits(location_id,franchise_id) where series_id is null;
create unique index canon_location_fit_series_v3_uq
  on canon.location_franchise_fits(location_id,franchise_id,series_id) where series_id is not null;
create unique index canon_location_fit_id_franchise_v3_uq
  on canon.location_franchise_fits(id,franchise_id);
create unique index canon_location_fit_id_location_v3_uq
  on canon.location_franchise_fits(id,location_id);
create index canon_location_fit_franchise_v3_idx on canon.location_franchise_fits(franchise_id,location_id);
comment on table canon.location_franchise_fits is
  'Canon-scoped storytelling suitability; hypothesis != canonical historical fact or publication approval.';

-- Reuse different cast members at the same real place without copying the place.
create table canon.location_character_uses (
  fit_id uuid not null,
  franchise_id uuid not null,
  character_id uuid not null,
  use_role text not null check (length(btrim(use_role)) > 0),
  narrative_note text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (fit_id,character_id,use_role),
  constraint canon_character_use_fit_franchise_v3 foreign key (fit_id,franchise_id)
    references canon.location_franchise_fits(id,franchise_id) on delete cascade,
  constraint canon_character_use_character_franchise_v3 foreign key (character_id,franchise_id)
    references canon.characters(id,franchise_id) on delete restrict
);
create index canon_location_character_v3_idx on canon.location_character_uses(character_id);

-- Gameplay is canonical-scoped: same clue can power different puzzles in different universes.
create unique index geo_location_clues_id_location_v3_uq on geo.location_clues(id,location_id);
create table canon.location_clue_uses (
  fit_id uuid not null,
  clue_id uuid not null,
  location_id uuid not null,
  mechanic_key text not null check (length(btrim(mechanic_key)) > 0),
  narrative_hook text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (fit_id,clue_id,mechanic_key),
  constraint canon_clue_use_fit_location_v3 foreign key (fit_id,location_id)
    references canon.location_franchise_fits(id,location_id) on delete cascade,
  constraint canon_clue_use_clue_location_v3 foreign key (clue_id,location_id)
    references geo.location_clues(id,location_id) on delete restrict
);
create index canon_location_clue_uses_clue_v3_idx on canon.location_clue_uses(clue_id);

-- Preserve current private-schema posture. No generic anon/authenticated policies.
-- Existing trusted RPC read models remain unchanged; no Player access is activated.
alter table geo.location_research_candidates enable row level security;
alter table geo.location_hierarchy enable row level security;
alter table geo.location_clues enable row level security;
alter table canon.location_franchise_fits enable row level security;
alter table canon.location_character_uses enable row level security;
alter table canon.location_clue_uses enable row level security;
revoke all on geo.location_research_candidates,geo.location_hierarchy,geo.location_clues
  from public,anon,authenticated,service_role;
revoke all on canon.location_franchise_fits,canon.location_character_uses,canon.location_clue_uses
  from public,anon,authenticated,service_role;
revoke execute on function geo.location_hierarchy_prevent_cycle_v3() from public,anon,authenticated;

-- Additive, idempotent archival intake for the 54 already linked Novi Sad V2/V3 facts.
-- No original fact, location, quest, or source record is modified.
insert into geo.location_research_candidates (
  city_id,source_key,external_research_id,location_id,source_fact_id,
  display_name,raw_v2,raw_v3,provenance
)
select f.city_id,'novi-sad-location-master-v3-20261028',f.metadata->>'candidate_id',
  f.location_id,f.id,coalesce(nullif(f.metadata->'location_master_v3'->'record'->>'name',''),
  f.metadata->>'candidate_id'),
  f.metadata->'original_v2_record',f.metadata->'location_master_v3'->'record',
  jsonb_build_object('fact_key',f.fact_key,'source','original_v2_and_v3_dossiers',
    'policy','default_allow_quest_qa_only_v1')
from geo.location_facts f
join geo.cities c on c.id=f.city_id and c.slug='novi-sad' and c.country_code='RS'
where f.fact_type='research_candidate' and f.metadata ? 'original_v2_record'
  and f.metadata ? 'location_master_v3'
  and nullif(f.metadata->>'candidate_id','') is not null
on conflict do nothing;

-- Import existing franchise fits ONLY as hypotheses, never as approved canon.
-- Avoid ambiguous franchise slugs in separate universes: only uniquely resolving slugs qualify.
with unique_franchises as (
  select slug,min(id::text)::uuid as franchise_id
  from canon.franchises group by slug having count(*)=1
), proposed as (
  select distinct on (f.location_id,uf.franchise_id)
    f.location_id,uf.franchise_id,f.id as fact_id,f.fact_key
  from geo.location_facts f
  join geo.cities c on c.id=f.city_id and c.slug='novi-sad' and c.country_code='RS'
  cross join lateral jsonb_array_elements_text(
    case when jsonb_typeof(f.metadata->'franchise_fit_hypotheses')='array'
      then f.metadata->'franchise_fit_hypotheses' else '[]'::jsonb end
  ) as slug(value)
  join unique_franchises uf on uf.slug=slug.value
  where f.fact_type='research_candidate' and f.location_id is not null
    and f.metadata ? 'location_master_v3'
  order by f.location_id,uf.franchise_id,f.fact_key
)
insert into canon.location_franchise_fits(
  location_id,franchise_id,source_fact_id,status,metadata
)
select location_id,franchise_id,fact_id,'hypothesis',
  jsonb_build_object('source_fact_key',fact_key,'source','novi-sad-v2-editorial-proposal',
    'not_canon_approval',true)
from proposed
on conflict do nothing;