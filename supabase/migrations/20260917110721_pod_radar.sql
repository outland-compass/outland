-- OUTLAND COMPASS: saved Land Search profiles and initial Montenegro Pod hunt.
-- Radar is the system, a Land Search is a saved hunt, and POD is an asset strategy.
-- Additive and idempotent. All listing claims remain unverified.

begin;

-- Early Radar candidates may precede a final World decision. A World is required only
-- when an evaluation is started, because evaluation criteria remain World-specific.
alter table land.candidates alter column world_id drop not null;
alter table land.candidates
  add column if not exists development_model text not null default 'UNDECIDED'
    check (development_model in ('POD','HOUSE','FLOATING','EXISTING_PROPERTY','UNDECIDED'));

comment on column land.candidates.development_model is
  'Intended realization strategy; independent of the acquired asset_kind and final World.';

create table if not exists land.search_profiles (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  name text not null,
  description text,
  asset_kind public.asset_kind not null default 'LAND',
  development_model text not null default 'UNDECIDED'
    check (development_model in ('POD','HOUSE','FLOATING','EXISTING_PROPERTY','UNDECIDED')),
  geographies text[] not null default '{}',
  price_priority_eur numeric(14,2),
  price_ceiling_eur numeric(14,2),
  area_min_m2 numeric(14,2),
  area_max_m2 numeric(14,2),
  criteria jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  last_run_at timestamptz,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (price_priority_eur is null or price_priority_eur >= 0),
  check (price_ceiling_eur is null or price_ceiling_eur >= 0),
  check (area_min_m2 is null or area_min_m2 > 0),
  check (area_max_m2 is null or area_max_m2 > 0),
  check (area_min_m2 is null or area_max_m2 is null or area_min_m2 <= area_max_m2)
);

create table if not exists land.candidate_search_profiles (
  candidate_id uuid not null references land.candidates(id) on delete cascade,
  search_profile_id uuid not null references land.search_profiles(id) on delete cascade,
  discovered_at timestamptz not null default now(),
  notes text,
  primary key (candidate_id, search_profile_id)
);

comment on table land.search_profiles is
  'Saved Land Search/Hunt definitions within Radar; not Worlds and not destination brands.';
comment on table land.candidate_search_profiles is
  'Links candidates to the saved hunt(s) through which they were discovered.';

alter table land.search_profiles enable row level security;
alter table land.candidate_search_profiles enable row level security;

create policy search_profiles_read on land.search_profiles for select to authenticated using (public.can_read());
create policy search_profiles_write_insert on land.search_profiles for insert to authenticated with check (public.can_analyze());
create policy search_profiles_write_update on land.search_profiles for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy search_profiles_write_delete on land.search_profiles for delete to authenticated using (public.can_admin());
create policy candidate_search_profiles_read on land.candidate_search_profiles for select to authenticated using (public.can_read());
create policy candidate_search_profiles_write_insert on land.candidate_search_profiles for insert to authenticated with check (public.can_analyze());
create policy candidate_search_profiles_write_update on land.candidate_search_profiles for update to authenticated using (public.can_analyze()) with check (public.can_analyze());
create policy candidate_search_profiles_write_delete on land.candidate_search_profiles for delete to authenticated using (public.can_analyze());

grant select,insert,update,delete on land.search_profiles to authenticated;
grant select,insert,update,delete on land.candidate_search_profiles to authenticated;

insert into land.search_profiles(
  code,name,description,asset_kind,development_model,geographies,
  price_priority_eur,price_ceiling_eur,area_min_m2,area_max_m2,criteria,last_run_at
) values (
  'MONTENEGRO_POD_LAND','Montenegro Pod Land Hunt',
  'Find the least expensive legally usable parcel that delivers an exceptional OUTLAND experience; do not optimize for budget utilization.',
  'LAND','POD',array['Piva / Plužine','Prokletije','Skadar Lake','Ulcinj hinterland / Šasko Lake'],
  15000,50000,400,3000,
  jsonb_build_object(
    'strategy','NATURE_VALUE_NOT_BUDGET_UTILIZATION','no_minimum_price',true,
    'price_bands',jsonb_build_array('UNDER_5K','5K_10K','10K_20K','20K_30K','30K_50K','OVER_50K'),
    'hard_gates',jsonb_build_array('exceptional_nature','privacy_and_silence','legal_access','clean_ownership','legal_development_path'),
    'ranking',jsonb_build_array('nature_to_capital','scarcity','privacy','legal_usability','network_value'),
    'cluster_preference','Piva complements LOST SIGNAL'
  ),now()
)
on conflict (code) do update set
  name=excluded.name,description=excluded.description,asset_kind=excluded.asset_kind,
  development_model=excluded.development_model,geographies=excluded.geographies,
  price_priority_eur=excluded.price_priority_eur,price_ceiling_eur=excluded.price_ceiling_eur,
  area_min_m2=excluded.area_min_m2,area_max_m2=excluded.area_max_m2,
  criteria=excluded.criteria,last_run_at=excluded.last_run_at,is_active=true,updated_at=now();

with rows(internal_name,title,region,municipality,settlement,asking_price,area_m2,property_type,description,access_summary,infrastructure_summary,next_action) as (values
 ('pod-pisce-piva','Pišče / Piva — small parcel scenario','Piva','Plužine','Pišče',7500::numeric,1500::numeric,'Agricultural land (listing claim)','Listing advertises €5/m² and explicitly mentions 1,000–2,000 m² parcels. Asking price shown is a 1,500 m² scenario, not a confirmed seller offer.',null,null,'Request exact pin/parcel, minimum divisible area, video, access, utilities and written planning position.'),
 ('pod-vladimir-sasko','Vladimir / Šasko Lake — small parcel scenario','Ulcinj hinterland','Ulcinj','Vladimir',6000,1500,'Agricultural land (listing claim)','Large holding advertised at €4/m² with stated subdivision possibility and views toward Šasko Lake, Solana and Velika Plaža. Price shown is a 1,500 m² scenario and is not confirmed.','Road claimed by seller','Water and electricity claimed by seller','Confirm minimum parcel, exact pin/cadastre, subdivision mechanics, access and legal Pod path.'),
 ('pod-rudnica-piva','Rudnica / Piva — estate with old house','Piva','Plužine','Rudnica',28000,21800,'Estate with old house (listing claim)','Large low-price estate. Existing house footprint may matter more than total land area. Road noise is a potential OUTLAND deal-breaker.','Adjacent to Nikšić–Plužine road',null,'Get exact pin; verify house registration/reconstruction rights; perform road-noise screen before visit.'),
 ('pod-rvasi-skadar','Rvaši / Skadar Lake','Skadar Lake','Cetinje','Rvaši',25000,2200,'Building land (listing claim)','Advertised around 4 km from Karuč, with two access roads, street lighting and ownership 1/1. Requires a genuine nature/view check; proximity to Karuč alone is insufficient.','Two roads claimed by seller','Street lighting claimed by seller','Request exact pin, photos in every direction, planning document and lake-view evidence.'),
 ('pod-brijeg-tara','Brijeg / Šćepan Polje — Tara edge','Tara–Piva cluster','Plužine','Brijeg / Šćepan Polje',null,11500,'Land near river (listing claim)','Advertised 25 m from Tara with price on request and claimed tourism potential. Flood, protection and legal-use gates are decisive.',null,null,'Obtain price and exact parcel; verify flood envelope, protected-area rules, tourism use and legal access.')
)
insert into land.candidates(world_id,status,title,internal_name,asset_kind,development_model,country_code,region,municipality,settlement,asking_price,currency,area_m2,property_type,description,access_summary,infrastructure_summary,next_action,date_discovered,listing_status,last_seen_at)
select null,'NEW',r.title,r.internal_name,'LAND','POD','ME',r.region,r.municipality,r.settlement,r.asking_price,'EUR',r.area_m2,r.property_type,r.description,r.access_summary,r.infrastructure_summary,r.next_action,current_date,'ACTIVE',now()
from rows r where not exists (select 1 from land.candidates c where c.internal_name=r.internal_name);

insert into land.candidate_search_profiles(candidate_id,search_profile_id,notes)
select c.id,p.id,'Initial live hunt; listing data unverified.'
from land.candidates c cross join land.search_profiles p
where c.internal_name in ('pod-pisce-piva','pod-vladimir-sasko','pod-rudnica-piva','pod-rvasi-skadar','pod-brijeg-tara')
  and p.code='MONTENEGRO_POD_LAND'
on conflict (candidate_id,search_profile_id) do update set notes=excluded.notes;

with rows(internal_name,source_name,source_url) as (values
 ('pod-pisce-piva','oglasi.me','https://oglasi.me/nekretnine/zemljiste/a-very-nice-big-property-in-the-dumitor-mountains-of-montenegro--og53601286me'),
 ('pod-vladimir-sasko','oglasi.me','https://oglasi.me/nekretnine/zemljiste/placeve-za-investiciju--og52483037me'),
 ('pod-rudnica-piva','oglasi.me','https://oglasi.me/nekretnine/zemljiste/na-prodaju-imanje-u-pivi-og42001315me'),
 ('pod-rvasi-skadar','oglasi.me','https://oglasi.me/nekretnine/zemljiste/prodajem-zemlljiste-rvasi--og52322175me'),
 ('pod-brijeg-tara','oglasi.me','https://oglasi.me/nekretnine/zemljiste/prodaja-zemljista--selo-brijeg--scepan-polje-og36088803me')
)
insert into land.candidate_sources(candidate_id,source_name,source_url,last_seen_at,listing_status,source_snapshot)
select c.id,r.source_name,r.source_url,now(),'ACTIVE',jsonb_build_object('verification_state','UNVERIFIED','captured_for','MONTENEGRO_POD_LAND')
from rows r join land.candidates c on c.internal_name=r.internal_name
on conflict (candidate_id,source_url) do update set last_seen_at=excluded.last_seen_at,listing_status=excluded.listing_status;

create or replace view land.v_candidate_radar with (security_invoker = true) as
select
  c.id,c.world_id,w.code as world_code,w.name as world_name,c.status,c.title,c.asset_kind,
  c.country_code,c.region,c.municipality,c.settlement,
  c.asking_price,c.currency,c.area_m2,c.price_per_m2,
  c.listing_status,c.last_seen_at,econ.total_phase1_capital,le.evaluation_id,le.compass_score,
  le.confidence_percent,gs.critical_failed_count,gs.critical_unknown_count,gs.failed_count,gs.unknown_count,
  case when coalesce(gs.critical_failed_count,0)>0 then 'BLOCKED' when le.compass_score>=90 then 'HOT'
    when le.compass_score>=80 then 'STRONG' when le.compass_score>=70 then 'WATCH'
    when le.compass_score is not null then 'LOW' else 'UNSCORED' end as recommendation,
  c.development_model,
  case when c.asking_price is null then 'PRICE_UNKNOWN' when c.asking_price < 5000 then 'UNDER_5K'
    when c.asking_price <= 10000 then '5K_10K' when c.asking_price <= 20000 then '10K_20K'
    when c.asking_price <= 30000 then '20K_30K' when c.asking_price <= 50000 then '30K_50K' else 'OVER_50K' end as land_price_band,
  sp.id as search_profile_id,sp.code as search_profile_code,sp.name as search_profile_name
from land.candidates c
left join shared.worlds w on w.id=c.world_id
left join land.candidate_economics econ on econ.candidate_id=c.id
left join land.v_candidate_latest_evaluation le on le.candidate_id=c.id
left join land.v_candidate_gate_summary gs on gs.candidate_id=c.id
left join lateral (
  select p.id,p.code,p.name from land.candidate_search_profiles cp
  join land.search_profiles p on p.id=cp.search_profile_id
  where cp.candidate_id=c.id order by cp.discovered_at limit 1
) sp on true;

grant select on land.v_candidate_radar to authenticated;

commit;
