-- 202609120002_wanderer_mobile_radar.sql
-- OUTLAND COMPASS: activate WANDERER as the first MOBILE ASSET acquisition radar.
-- Idempotent configuration/data migration. No schema changes.

begin;

-- 1. Activate the live WANDERER search profile.
update shared.worlds
set radar_enabled = true,
    target_capital_min_eur = 25000,
    target_capital_max_eur = 40000,
    reunderwrite_above_eur = 40000,
    target_profile = coalesce(target_profile, '{}'::jsonb) || jsonb_build_object(
      'mobile_asset_type', 'CAMPERVAN',
      'exceptional_max_eur', 45000,
      'max_mileage_km_preferred', 150000,
      'max_weight_kg', 3500,
      'conversion_quality', jsonb_build_array('FACTORY', 'PROFESSIONAL'),
      'fixed_high_roof', true,
      'four_season', 'REQUIRED',
      'heating', 'REQUIRED',
      'shower', 'REQUIRED',
      'toilet', 'REQUIRED',
      'awd', 'BONUS',
      'aesthetic_fit', 'HIGH_PRIORITY',
      'direct_individual_listing_required', true,
      'active_listing_verification_required', true,
      'ready_to_wander_capex', true
    ),
    search_notes = 'WANDERER V1: used complete factory/professional campervan. Target EUR 25-40k; exceptional <=45k. Fixed high roof, <=3.5t, <=150k km preferred, strong four-season potential, WC/shower, good energy autonomy, OUTLAND-worthy aesthetics. AWD is a bonus, not a hard gate. Rank verified live listings against the current benchmark.',
    updated_at = now()
where code = 'WANDERER' and asset_kind = 'MOBILE';

-- 2. Dimension weights use the existing Compass five-dimension engine.
insert into land.world_dimension_weights(world_id, dimension, weight)
select w.id, x.dimension::public.score_dimension, x.weight
from shared.worlds w
cross join (values
  ('PLACE',       0.05::numeric),
  ('FEASIBILITY', 0.40::numeric),
  ('ECONOMICS',   0.20::numeric),
  ('OUTLAND',     0.20::numeric),
  ('NETWORK',     0.15::numeric)
) x(dimension, weight)
where w.code = 'WANDERER'
on conflict (world_id, dimension) do update set weight = excluded.weight;

-- 3. WANDERER-specific scoring criteria. Item weights within dimensions reproduce the
-- agreed 20/15/15/15/10/10/5/5/5 overall priorities through the dimension weights above.
insert into land.world_score_criteria(world_id, dimension, code, label, description, item_weight, is_required, is_active, sort_order)
select w.id, x.dimension::public.score_dimension, x.code, x.label, x.description, x.item_weight, x.is_required, true, x.sort_order
from shared.worlds w
cross join (values
  ('FEASIBILITY','MECHANICAL_CONDITION','Mechanical condition / reliability','Engine, transmission, chassis, corrosion, mileage plausibility and service condition.',2.00::numeric,true,10::smallint),
  ('FEASIBILITY','CAMPER_BUILD_QUALITY','Camper build quality','Factory/professional conversion quality, moisture integrity, gas/electrical/plumbing workmanship.',1.50::numeric,true,20::smallint),
  ('FEASIBILITY','FOUR_SEASON_CAPABILITY','Four-season capability','Insulation, heating and frost resilience suitable for OUTLAND shoulder/winter use.',1.50::numeric,true,30::smallint),
  ('ECONOMICS','VALUE_FOR_MONEY','Price / value','Purchase price and Ready-to-Wander CAPEX versus condition, equipment and alternatives.',1.50::numeric,true,10::smallint),
  ('OUTLAND','OUTLAND_AESTHETIC','OUTLAND aesthetic fit','Clean, distinctive, modern visual character; must not feel like an improvised DIY van.',1.00::numeric,true,10::smallint),
  ('NETWORK','ENERGY_AUTONOMY','Energy autonomy','House battery, solar, inverter, shore power, ventilation/AC readiness and practical off-grid endurance.',1.00::numeric,true,10::smallint),
  ('PLACE','LAYOUT_USABILITY','Layout / usability','Compact living quality, bed, kitchen, WC/shower, storage and everyday two-person usability.',0.50::numeric,true,10::smallint),
  ('NETWORK','TRACTION_ACCESS','Traction / access','Traction aids, tyres and AWD where available. AWD is a bonus rather than a hard requirement.',0.50::numeric,false,20::smallint),
  ('ECONOMICS','RESALE_LIQUIDITY','Resale / liquidity','Brand strength, marketability, expected depreciation and ease of resale.',0.50::numeric,true,20::smallint)
) x(dimension, code, label, description, item_weight, is_required, sort_order)
where w.code = 'WANDERER'
on conflict (world_id, code) do update set
  dimension = excluded.dimension,
  label = excluded.label,
  description = excluded.description,
  item_weight = excluded.item_weight,
  is_required = excluded.is_required,
  is_active = true,
  sort_order = excluded.sort_order;

-- 4. Critical acquisition/DD gates.
insert into land.world_gate_definitions(world_id, code, category, label, description, is_critical, sort_order, is_active)
select w.id, x.code, x.category, x.label, x.description, x.is_critical, x.sort_order, true
from shared.worlds w
cross join (values
  ('VIN_VERIFIED','LEGAL','VIN verified','VIN matches registration and physical vehicle.',true,10::smallint),
  ('SERVICE_HISTORY','MECHANICAL','Service history acceptable','Service records and mileage history are credible enough for acquisition.',true,20::smallint),
  ('NO_MAJOR_ACCIDENT','MECHANICAL','No major accident issue','No unresolved major accident or structural repair concern.',true,30::smallint),
  ('NO_STRUCTURAL_RUST','MECHANICAL','No structural rust','No structural corrosion requiring major repair.',true,40::smallint),
  ('NO_WATER_INGRESS','HABITATION','No water ingress / damp','Moisture test and inspection show no material leak or damp issue.',true,50::smallint),
  ('CAMPER_ELECTRICS_SAFE','SAFETY','Camper electrics safe','12V/230V system is safe and professionally executed.',true,60::smallint),
  ('GAS_SYSTEM_SAFE','SAFETY','Gas system safe','Gas installation and inspection are valid and safe.',true,70::smallint),
  ('HOMOLOGATION_VALID','LEGAL','Registration / homologation valid','Vehicle and camper conversion are legally registered/homologated for intended use.',true,80::smallint),
  ('PAYLOAD_ACCEPTABLE','LEGAL','Payload acceptable','Realistic operating payload remains acceptable within the <=3.5t target.',true,90::smallint),
  ('WINTER_CAPABILITY','HABITATION','Winter capability acceptable','Heating, insulation and water-system configuration support the intended four-season use.',true,100::smallint)
) x(code, category, label, description, is_critical, sort_order)
where w.code = 'WANDERER'
on conflict (world_id, code) do update set
  category = excluded.category,
  label = excluded.label,
  description = excluded.description,
  is_critical = excluded.is_critical,
  sort_order = excluded.sort_order,
  is_active = true;

-- 5. Current verified benchmark candidate. No score is invented: evaluation remains pending.
with w as (
  select id from shared.worlds where code = 'WANDERER'
), candidate_upsert as (
  insert into land.candidates(
    world_id, status, title, internal_name, asset_kind, country_code, region, settlement,
    asking_price, currency, property_type, description, infrastructure_summary, next_action,
    target_offer, max_price, date_discovered, last_seen_at, listing_status
  )
  select
    w.id, 'SHORTLIST'::public.candidate_status,
    'Pössl Summit 600 Plus — 2018 / 52,500 km',
    'WANDERER BENCHMARK — Pössl Summit 600 Plus',
    'MOBILE'::public.asset_kind, 'DE', 'North Rhine-Westphalia', 'Bielefeld',
    39950, 'EUR', 'CAMPERVAN',
    'Current WANDERER benchmark. Pössl Summit 600 Plus, model/build year 2018, first registration 11/2018, Citroën diesel 120 kW / 163 PS, manual, 52,500 km, 5.99 m x 2.05 m x 2.61 m, 3,500 kg, 3 sleeping places. Private listing.',
    'Kitchen, toilet, warm-water boiler, Winterpaket, Traction+, Thule 3.75 m awning, second 95Ah habitation battery, Gas Duo Control CS, reversing camera, tow hitch. Solar, lithium, living-area AC and fully frost-protected water system are not confirmed.',
    'Run WANDERER DD: VIN/service/accident/moisture/rust, payload, gas/electrics, winter water protection. Confirm whether listed Klimaanlage is cab-only. Negotiate only after critical gates pass.',
    38500, 40000, current_date, now(), 'ACTIVE'::public.listing_status
  from w
  where not exists (
    select 1 from land.candidate_sources cs
    where cs.source_url = 'https://www.caraworld.de/wohnmobile/poessl/summit/28130718/poessl-summit-600-plus-gepflegt-aus-1-hand.html'
  )
  returning id
), existing_candidate as (
  select cs.candidate_id as id
  from land.candidate_sources cs
  where cs.source_url = 'https://www.caraworld.de/wohnmobile/poessl/summit/28130718/poessl-summit-600-plus-gepflegt-aus-1-hand.html'
  limit 1
), chosen as (
  select id from candidate_upsert
  union all
  select id from existing_candidate
  limit 1
), source_upsert as (
  insert into land.candidate_sources(candidate_id, source_name, source_url, source_listing_id, first_seen_at, last_seen_at, listing_status, source_snapshot)
  select
    c.id, 'Caraworld',
    'https://www.caraworld.de/wohnmobile/poessl/summit/28130718/poessl-summit-600-plus-gepflegt-aus-1-hand.html',
    'cw-28130718', now(), now(), 'ACTIVE'::public.listing_status,
    jsonb_build_object(
      'verified_at', now(),
      'seller_type', 'PRIVATE',
      'location', 'Bielefeld',
      'price_eur', 39950,
      'model_year', 2018,
      'first_registration', '11/2018',
      'mileage_km', 52500,
      'power_kw', 120,
      'power_ps', 163,
      'length_cm', 599,
      'width_cm', 205,
      'height_cm', 261,
      'gross_weight_kg', 3500,
      'sleeping_places', 3,
      'photo_count', 9,
      'tuv_until', '07/2028',
      'gas_check_until', '07/2028'
    )
  from chosen c
  on conflict (candidate_id, source_url) do update set
    last_seen_at = excluded.last_seen_at,
    listing_status = excluded.listing_status,
    source_listing_id = excluded.source_listing_id,
    source_snapshot = excluded.source_snapshot
  returning id, candidate_id
), source_chosen as (
  select id, candidate_id from source_upsert
  union all
  select cs.id, cs.candidate_id
  from land.candidate_sources cs
  join chosen c on c.id = cs.candidate_id
  where cs.source_url = 'https://www.caraworld.de/wohnmobile/poessl/summit/28130718/poessl-summit-600-plus-gepflegt-aus-1-hand.html'
  limit 1
)
insert into land.candidate_price_history(candidate_id, source_id, observed_at, price, currency, note)
select sc.candidate_id, sc.id, now(), 39950, 'EUR', 'Verified active Caraworld asking price at WANDERER benchmark creation.'
from source_chosen sc
where not exists (
  select 1 from land.candidate_price_history ph
  where ph.candidate_id = sc.candidate_id and ph.price = 39950 and ph.currency = 'EUR'
);

-- 6. Initialize the benchmark gates from the WANDERER definitions. They intentionally start UNKNOWN.
insert into land.candidate_gates(candidate_id, source_definition_id, gate_code, category, gate_label, is_critical)
select c.id, g.id, g.code, g.category, g.label, g.is_critical
from land.candidates c
join shared.worlds w on w.id = c.world_id and w.code = 'WANDERER'
join land.world_gate_definitions g on g.world_id = w.id and g.is_active = true
where exists (
  select 1 from land.candidate_sources cs
  where cs.candidate_id = c.id
    and cs.source_url = 'https://www.caraworld.de/wohnmobile/poessl/summit/28130718/poessl-summit-600-plus-gepflegt-aus-1-hand.html'
)
on conflict (candidate_id, gate_code) do nothing;

commit;
