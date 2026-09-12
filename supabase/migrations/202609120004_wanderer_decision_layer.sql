-- Minimal WANDERER decision layer: only fields needed to compare a camper to the current benchmark.
create table if not exists land.mobile_candidate_specs (
  candidate_id uuid primary key references land.candidates(id) on delete cascade,
  model_year integer,
  mileage_km integer,
  length_mm integer,
  gross_weight_kg integer,
  heating_type text,
  solar_w integer,
  battery_summary text,
  indoor_shower boolean,
  toilet_type text,
  drivetrain text,
  winter_summary text,
  updated_at timestamptz not null default now()
);

alter table land.mobile_candidate_specs enable row level security;

create policy "mobile_candidate_specs_read"
  on land.mobile_candidate_specs for select
  to authenticated
  using (can_read());
create policy "mobile_candidate_specs_insert"
  on land.mobile_candidate_specs for insert
  to authenticated
  with check (can_analyze());
create policy "mobile_candidate_specs_update"
  on land.mobile_candidate_specs for update
  to authenticated
  using (can_analyze())
  with check (can_analyze());
create policy "mobile_candidate_specs_delete"
  on land.mobile_candidate_specs for delete
  to authenticated
  using (can_admin());

insert into land.mobile_candidate_specs (
  candidate_id, model_year, mileage_km, length_mm, gross_weight_kg,
  heating_type, solar_w, battery_summary, indoor_shower, toilet_type,
  drivetrain, winter_summary
)
select c.id, 2018, 52500, 5990, 3500,
       'Gas heating / Winterpaket (listing; exact heater model unverified)', null,
       '2 x 95 Ah house batteries listed; chemistry unverified', true,
       'Cassette WC / exact model unverified', 'FWD + Traction+',
       'Winterpaket listed; full frost protection not yet verified'
from land.candidates c join shared.worlds w on w.id=c.world_id
where w.code='WANDERER' and c.title ilike 'Pössl Summit 600 Plus%'
on conflict (candidate_id) do update set
  model_year=excluded.model_year,mileage_km=excluded.mileage_km,length_mm=excluded.length_mm,
  gross_weight_kg=excluded.gross_weight_kg,heating_type=excluded.heating_type,solar_w=excluded.solar_w,
  battery_summary=excluded.battery_summary,indoor_shower=excluded.indoor_shower,toilet_type=excluded.toilet_type,
  drivetrain=excluded.drivetrain,winter_summary=excluded.winter_summary,updated_at=now();

insert into land.candidate_economics (
  candidate_id,likely_purchase_price,transaction_legal_costs,immediate_infrastructure_safety_capex,
  minimum_usable_state_capex,first_unit_fitout_capex,phase1_capital_excluding_purchase,total_phase1_capital,assumptions
)
select c.id,38500,1500,1000,0,2000,4500,43000,
       'WANDERER Ready-to-Wander working estimate: target purchase €38.5k + ~€1.5k import/registration + ~€1k initial service/safety reserve + ~€2k minimal OUTLAND/off-grid retrofit. Verify before negotiation.'
from land.candidates c join shared.worlds w on w.id=c.world_id
where w.code='WANDERER' and c.title ilike 'Pössl Summit 600 Plus%'
on conflict (candidate_id) do update set
  likely_purchase_price=excluded.likely_purchase_price,transaction_legal_costs=excluded.transaction_legal_costs,
  immediate_infrastructure_safety_capex=excluded.immediate_infrastructure_safety_capex,
  minimum_usable_state_capex=excluded.minimum_usable_state_capex,first_unit_fitout_capex=excluded.first_unit_fitout_capex,
  phase1_capital_excluding_purchase=excluded.phase1_capital_excluding_purchase,total_phase1_capital=excluded.total_phase1_capital,
  assumptions=excluded.assumptions,updated_at=now();