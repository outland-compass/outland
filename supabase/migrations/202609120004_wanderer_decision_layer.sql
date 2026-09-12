-- Minimal WANDERER decision layer: only fields needed to compare a camper to the current benchmark.
create table land.mobile_candidate_specs (
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
create policy "mobile_candidate_specs_read" on land.mobile_candidate_specs for select to authenticated using (can_read());
create policy "mobile_candidate_specs_insert" on land.mobile_candidate_specs for insert to authenticated with check (can_analyze());
create policy "mobile_candidate_specs_update" on land.mobile_candidate_specs for update to authenticated using (can_analyze()) with check (can_analyze());
create policy "mobile_candidate_specs_delete" on land.mobile_candidate_specs for delete to authenticated using (can_admin());

insert into land.mobile_candidate_specs (candidate_id,model_year,mileage_km,length_mm,gross_weight_kg,heating_type,solar_w,battery_summary,indoor_shower,toilet_type,drivetrain,winter_summary)
select c.id,2018,52500,5990,3500,'Gas heating / Winterpaket (listing; exact heater model unverified)',null,'2 x 95 Ah house batteries listed; chemistry unverified',true,'Cassette WC / exact model unverified','FWD + Traction+','Winterpaket listed; full frost protection not yet verified'
from land.candidates c join shared.worlds w on w.id=c.world_id
where w.code='WANDERER' and c.title ilike 'Pössl Summit 600 Plus%';

-- Ready-to-Wander is deliberately not persisted here yet. The existing candidate_economics
-- audit trigger currently fails on candidate_economics rows without an id column. V1.1 computes
-- the working estimate in the UI from target offer + explicit conservative allowances instead of
-- broadening this change into an unrelated audit-system fix.