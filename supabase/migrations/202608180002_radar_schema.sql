-- 202608180002_radar_schema.sql
-- OUTLAND COMPASS v0.1 / M2
-- Property Radar domain schema.

create table public.worlds (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  environment text,
  archetype text,
  inner_movement text,
  asset_kind public.asset_kind not null,
  radar_enabled boolean not null default true,
  target_geography text,
  target_area_min_m2 numeric(14,2),
  target_area_max_m2 numeric(14,2),
  target_capital_min_eur numeric(14,2),
  target_capital_max_eur numeric(14,2),
  reunderwrite_above_eur numeric(14,2),
  target_profile jsonb not null default '{}'::jsonb,
  search_notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.score_dimensions (
  code public.score_dimension primary key,
  label text not null,
  sort_order smallint not null unique
);

create table public.world_dimension_weights (
  world_id uuid not null references public.worlds(id) on delete cascade,
  dimension public.score_dimension not null references public.score_dimensions(code),
  weight numeric(6,5) not null check (weight > 0 and weight <= 1),
  primary key (world_id, dimension)
);

create table public.world_score_criteria (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  dimension public.score_dimension not null references public.score_dimensions(code),
  code text not null,
  label text not null,
  description text,
  item_weight numeric(8,4) not null default 1 check (item_weight > 0),
  is_required boolean not null default true,
  is_active boolean not null default true,
  sort_order smallint not null default 100,
  created_at timestamptz not null default now(),
  unique (world_id, code)
);

create table public.world_gate_definitions (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id) on delete cascade,
  code text not null,
  category text not null,
  label text not null,
  description text,
  is_critical boolean not null default false,
  sort_order smallint not null default 100,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (world_id, code)
);

create table public.candidates (
  id uuid primary key default gen_random_uuid(),
  world_id uuid not null references public.worlds(id),
  status public.candidate_status not null default 'NEW',
  title text not null,
  internal_name text,
  asset_kind public.asset_kind not null,
  country_code char(2),
  region text,
  municipality text,
  settlement text,
  address_text text,
  parcel_number text,
  latitude numeric(9,6) check (latitude between -90 and 90),
  longitude numeric(9,6) check (longitude between -180 and 180),
  asking_price numeric(14,2) check (asking_price is null or asking_price >= 0),
  currency char(3) not null default 'EUR',
  area_m2 numeric(14,2) check (area_m2 is null or area_m2 > 0),
  price_per_m2 numeric(14,2)
    generated always as (
      case when asking_price is not null and area_m2 is not null and area_m2 > 0
           then round(asking_price / area_m2, 2)
           else null end
    ) stored,
  ownership_type text,
  property_type text,
  description text,
  terrain text,
  orientation text,
  access_summary text,
  infrastructure_summary text,
  next_action text,
  target_offer numeric(14,2),
  max_price numeric(14,2),
  date_discovered date not null default current_date,
  last_seen_at timestamptz,
  listing_status public.listing_status not null default 'UNKNOWN',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.signals (
  id uuid primary key default gen_random_uuid(),
  world_id uuid references public.worlds(id),
  status public.signal_status not null default 'NEW',
  source_name text,
  source_url text,
  source_listing_id text,
  raw_title text,
  raw_description text,
  raw_location text,
  raw_price numeric(14,2),
  raw_currency char(3),
  raw_area_m2 numeric(14,2),
  raw_payload jsonb not null default '{}'::jsonb,
  extracted_payload jsonb not null default '{}'::jsonb,
  extraction_status text,
  discovered_at timestamptz not null default now(),
  last_seen_at timestamptz,
  promoted_candidate_id uuid references public.candidates(id),
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_url)
);

create table public.candidate_sources (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  signal_id uuid references public.signals(id) on delete set null,
  source_name text not null,
  source_url text,
  source_listing_id text,
  first_seen_at timestamptz not null default now(),
  last_seen_at timestamptz,
  listing_status public.listing_status not null default 'UNKNOWN',
  source_snapshot jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (candidate_id, source_url)
);

create table public.candidate_price_history (
  id bigint generated always as identity primary key,
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  source_id uuid references public.candidate_sources(id) on delete set null,
  observed_at timestamptz not null default now(),
  price numeric(14,2) not null check (price >= 0),
  currency char(3) not null default 'EUR',
  note text
);

create table public.candidate_media (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  source_id uuid references public.candidate_sources(id) on delete set null,
  media_type text not null default 'IMAGE',
  external_url text,
  storage_path text,
  caption text,
  sort_order smallint not null default 100,
  created_at timestamptz not null default now(),
  check (external_url is not null or storage_path is not null)
);

create table public.candidate_economics (
  candidate_id uuid primary key references public.candidates(id) on delete cascade,
  likely_purchase_price numeric(14,2),
  transaction_legal_costs numeric(14,2),
  immediate_infrastructure_safety_capex numeric(14,2),
  minimum_usable_state_capex numeric(14,2),
  first_unit_fitout_capex numeric(14,2),
  phase1_capital_excluding_purchase numeric(14,2)
    generated always as (
      coalesce(transaction_legal_costs,0)
      + coalesce(immediate_infrastructure_safety_capex,0)
      + coalesce(minimum_usable_state_capex,0)
      + coalesce(first_unit_fitout_capex,0)
    ) stored,
  total_phase1_capital numeric(14,2)
    generated always as (
      coalesce(likely_purchase_price,0)
      + coalesce(transaction_legal_costs,0)
      + coalesce(immediate_infrastructure_safety_capex,0)
      + coalesce(minimum_usable_state_capex,0)
      + coalesce(first_unit_fitout_capex,0)
    ) stored,
  annual_revenue_conservative numeric(14,2),
  annual_revenue_base numeric(14,2),
  annual_revenue_upside numeric(14,2),
  key_downside text,
  assumptions text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now()
);

create table public.evaluations (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  world_id uuid not null references public.worlds(id),
  version_no integer not null,
  status public.evaluation_status not null default 'DRAFT',
  why_compass_likes_it text[] not null default '{}',
  concerns text[] not null default '{}',
  evaluator_note text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  finalized_at timestamptz,
  unique (candidate_id, version_no)
);

create table public.evaluation_dimension_weights (
  evaluation_id uuid not null references public.evaluations(id) on delete cascade,
  dimension public.score_dimension not null,
  weight numeric(6,5) not null check (weight > 0 and weight <= 1),
  primary key (evaluation_id, dimension)
);

create table public.evaluation_items (
  id uuid primary key default gen_random_uuid(),
  evaluation_id uuid not null references public.evaluations(id) on delete cascade,
  source_criterion_id uuid references public.world_score_criteria(id) on delete set null,
  dimension public.score_dimension not null,
  criterion_code text not null,
  criterion_label text not null,
  item_weight numeric(8,4) not null check (item_weight > 0),
  is_required boolean not null default true,
  score smallint check (score between 0 and 100),
  confidence_percent smallint not null default 0 check (confidence_percent between 0 and 100),
  evidence_state public.evidence_state not null default 'UNKNOWN',
  rationale text,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  unique (evaluation_id, criterion_code)
);

create table public.candidate_gates (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  source_definition_id uuid references public.world_gate_definitions(id) on delete set null,
  gate_code text not null,
  category text not null,
  gate_label text not null,
  is_critical boolean not null default false,
  state public.gate_state not null default 'UNKNOWN',
  notes text,
  verified_by uuid references auth.users(id),
  verified_at timestamptz,
  updated_by uuid references auth.users(id),
  updated_at timestamptz not null default now(),
  unique (candidate_id, gate_code)
);

create table public.dd_items (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  gate_id uuid references public.candidate_gates(id) on delete set null,
  category text not null,
  title text not null,
  description text,
  status public.dd_status not null default 'OPEN',
  severity public.dd_severity not null default 'IMPORTANT',
  owner_id uuid references auth.users(id),
  due_date date,
  next_step text,
  notes text,
  verified_by uuid references auth.users(id),
  verified_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  storage_bucket text not null default 'compass-evidence',
  storage_path text not null,
  original_filename text not null,
  mime_type text,
  size_bytes bigint check (size_bytes is null or size_bytes >= 0),
  document_type text,
  title text,
  source_name text,
  source_url text,
  captured_at timestamptz,
  uploaded_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  unique (storage_bucket, storage_path)
);

create table public.evidence_items (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  gate_id uuid references public.candidate_gates(id) on delete cascade,
  dd_item_id uuid references public.dd_items(id) on delete cascade,
  evaluation_item_id uuid references public.evaluation_items(id) on delete cascade,
  document_id uuid references public.documents(id) on delete set null,
  evidence_type public.evidence_type not null,
  verification_state public.verification_state not null default 'UNVERIFIED',
  title text not null,
  statement text,
  source_url text,
  observed_at timestamptz,
  verified_by uuid references auth.users(id),
  verified_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  check (num_nonnulls(gate_id, dd_item_id, evaluation_item_id) <= 1)
);

create table public.notes (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  note_type text not null default 'GENERAL',
  body text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.visits (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  visited_at timestamptz not null,
  visited_by uuid references auth.users(id),
  weather_note text,
  access_note text,
  nature_note text,
  infrastructure_note text,
  overall_note text,
  latitude numeric(9,6),
  longitude numeric(9,6),
  created_at timestamptz not null default now()
);

create table public.decisions (
  id uuid primary key default gen_random_uuid(),
  candidate_id uuid not null references public.candidates(id) on delete cascade,
  decision public.decision_type not null,
  reason text not null,
  previous_status public.candidate_status,
  resulting_status public.candidate_status,
  target_offer numeric(14,2),
  max_price numeric(14,2),
  decided_by uuid references auth.users(id),
  decided_at timestamptz not null default now()
);

create table public.assets (
  id uuid primary key default gen_random_uuid(),
  source_candidate_id uuid unique references public.candidates(id) on delete set null,
  world_id uuid not null references public.worlds(id),
  name text not null,
  asset_kind public.asset_kind not null,
  acquired_at date,
  acquisition_price numeric(14,2),
  currency char(3) not null default 'EUR',
  status text not null default 'ACQUIRED',
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.activities (
  id bigint generated always as identity primary key,
  candidate_id uuid references public.candidates(id) on delete cascade,
  entity_type text not null,
  entity_id text,
  action text not null,
  actor_id uuid references auth.users(id),
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

-- Core indexes used by Radar/DD.
create index candidates_world_status_idx on public.candidates(world_id, status);
create index candidates_location_idx on public.candidates(country_code, region, municipality);
create index candidates_price_idx on public.candidates(asking_price);
create index candidates_area_idx on public.candidates(area_m2);
create index signals_status_discovered_idx on public.signals(status, discovered_at desc);
create index candidate_sources_candidate_idx on public.candidate_sources(candidate_id);
create index candidate_price_history_candidate_time_idx on public.candidate_price_history(candidate_id, observed_at desc);
create index evaluations_candidate_created_idx on public.evaluations(candidate_id, created_at desc);
create index evaluation_items_evaluation_idx on public.evaluation_items(evaluation_id);
create index candidate_gates_candidate_state_idx on public.candidate_gates(candidate_id, state);
create index dd_items_candidate_status_idx on public.dd_items(candidate_id, status);
create index evidence_candidate_idx on public.evidence_items(candidate_id, created_at desc);
create index documents_candidate_idx on public.documents(candidate_id, created_at desc);
create index decisions_candidate_time_idx on public.decisions(candidate_id, decided_at desc);
create index activities_candidate_time_idx on public.activities(candidate_id, created_at desc);

-- updated_at triggers
create trigger worlds_set_updated_at before update on public.worlds
for each row execute function public.set_updated_at();
create trigger candidates_set_updated_at before update on public.candidates
for each row execute function public.set_updated_at();
create trigger signals_set_updated_at before update on public.signals
for each row execute function public.set_updated_at();
create trigger candidate_economics_set_updated_at before update on public.candidate_economics
for each row execute function public.set_updated_at();
create trigger evaluation_items_set_updated_at before update on public.evaluation_items
for each row execute function public.set_updated_at();
create trigger candidate_gates_set_updated_at before update on public.candidate_gates
for each row execute function public.set_updated_at();
create trigger dd_items_set_updated_at before update on public.dd_items
for each row execute function public.set_updated_at();
create trigger notes_set_updated_at before update on public.notes
for each row execute function public.set_updated_at();
create trigger assets_set_updated_at before update on public.assets
for each row execute function public.set_updated_at();
