-- 202608210001_outland_strategy_update.sql
-- OUTLAND COMPASS strategy update: add ALIKI World.
-- Additive/config-only. Does not touch evaluations, evaluation_items,
-- evaluation_dimension_weights, or candidate_gates (historical snapshots),
-- and does not touch the four original M2 migrations or seed.sql.

begin;

-- 1. ALIKI World.
insert into public.worlds(
  code,name,environment,archetype,inner_movement,asset_kind,radar_enabled,
  target_geography,target_area_min_m2,target_area_max_m2,
  target_capital_min_eur,target_capital_max_eur,reunderwrite_above_eur,
  target_profile
) values
('ALIKI','ALIKI','Sea','ARCHAEOLOGICAL / COASTAL','ANCHOR','LAND',true,
 'Aliki, Thassos, Greece / strategically relevant nearby south-east Thassos locations',
 null,null,null,null,null,
 '{"priority":{"sea_relationship":"VERY_HIGH","archaeological_landscape":"VERY_HIGH","privacy":"HIGH","legal_buildability":"GATE","archaeological_restrictions":"GATE","hospitality_use":"HIGH"}}')
on conflict (code) do update set
  name=excluded.name,
  environment=excluded.environment,
  archetype=excluded.archetype,
  inner_movement=excluded.inner_movement,
  asset_kind=excluded.asset_kind,
  radar_enabled=excluded.radar_enabled,
  target_geography=excluded.target_geography,
  target_area_min_m2=excluded.target_area_min_m2,
  target_area_max_m2=excluded.target_area_max_m2,
  target_capital_min_eur=excluded.target_capital_min_eur,
  target_capital_max_eur=excluded.target_capital_max_eur,
  reunderwrite_above_eur=excluded.reunderwrite_above_eur,
  target_profile=excluded.target_profile;

-- 2. ALIKI dimension weights.
-- PLACE/FEASIBILITY tied highest (exceptional place, but archaeology/protection can kill the
-- project); ECONOMICS secondary; OUTLAND high; NETWORK low but non-zero. Sums to 1.00, matching
-- the constraint used by every other World's weight set.
with aw as (select id from public.worlds where code='ALIKI'),
weights(dimension,weight) as (values
 ('PLACE'::public.score_dimension,0.30::numeric),
 ('FEASIBILITY'::public.score_dimension,0.30::numeric),
 ('ECONOMICS'::public.score_dimension,0.15::numeric),
 ('OUTLAND'::public.score_dimension,0.20::numeric),
 ('NETWORK'::public.score_dimension,0.05::numeric)
)
insert into public.world_dimension_weights(world_id,dimension,weight)
select aw.id,w.dimension,w.weight
from aw cross join weights w
on conflict (world_id,dimension) do update set weight=excluded.weight;

-- 3. ALIKI scoring criteria.
with aw as (select id from public.worlds where code='ALIKI'),
criteria(dimension,code,label,item_weight,sort_order) as (values
 ('PLACE'::public.score_dimension,'sea_relationship','Sea relationship / view / swimming',1.4,10),
 ('PLACE'::public.score_dimension,'place_character','Exceptional sense of place',1.3,20),
 ('PLACE'::public.score_dimension,'privacy_immersion','Privacy and immersion',1.1,30),
 ('PLACE'::public.score_dimension,'archaeological_landscape_character','Archaeological / ancient landscape character',1.0,40),
 ('PLACE'::public.score_dimension,'natural_beauty','Natural beauty / coastal setting',0.8,50),

 ('FEASIBILITY'::public.score_dimension,'legal_buildability','Legal / buildability confidence',1.4,10),
 ('FEASIBILITY'::public.score_dimension,'archaeological_authority_restrictions','Archaeological-authority / zone compliance',1.4,20),
 ('FEASIBILITY'::public.score_dimension,'protected_area_restrictions','Protected-area / environmental restrictions',1.2,30),
 ('FEASIBILITY'::public.score_dimension,'hospitality_use_feasibility','Hospitality / commercial-use feasibility',1.1,40),
 ('FEASIBILITY'::public.score_dimension,'utilities_feasibility','Water / wastewater / power feasibility',1.0,50),

 ('ECONOMICS'::public.score_dimension,'price_attractiveness','Purchase-price attractiveness',1.2,10),
 ('ECONOMICS'::public.score_dimension,'hidden_capex','Hidden CAPEX / minimum usable state',1.0,20),
 ('ECONOMICS'::public.score_dimension,'premium_adr_potential','Premium hospitality ADR potential',1.1,30),
 ('ECONOMICS'::public.score_dimension,'seasonality','Seasonality resilience',0.8,40),
 ('ECONOMICS'::public.score_dimension,'appreciation_exit','Appreciation / exit potential',0.8,50),

 ('OUTLAND'::public.score_dimension,'world_identity','ALIKI identity fit',1.3,10),
 ('OUTLAND'::public.score_dimension,'story_potential','Archaeological / OUTLAND story potential',1.2,20),
 ('OUTLAND'::public.score_dimension,'mystery_potential','Mystery potential',0.8,30),
 ('OUTLAND'::public.score_dimension,'emotional_character','Emotional character',1.1,40),
 ('OUTLAND'::public.score_dimension,'lifestyle_value','Personal / lifestyle value',0.7,50),

 ('NETWORK'::public.score_dimension,'portfolio_differentiation','Portfolio differentiation',1.1,10),
 ('NETWORK'::public.score_dimension,'seasonal_complementarity','Seasonal complementarity',0.9,20),
 ('NETWORK'::public.score_dimension,'cross_sell','Cross-world travel / cross-sell',0.7,30),
 ('NETWORK'::public.score_dimension,'network_role','Strategic network role',0.9,40)
)
insert into public.world_score_criteria(world_id,dimension,code,label,item_weight,sort_order)
select aw.id,c.dimension,c.code,c.label,c.item_weight,c.sort_order
from aw cross join criteria c
on conflict (world_id,code) do update set
 dimension=excluded.dimension,label=excluded.label,item_weight=excluded.item_weight,sort_order=excluded.sort_order,is_active=true;

-- 4. ALIKI gate definitions.
-- Reuses existing LAND-template gate codes where semantically equivalent; adds only the two
-- gates with no existing equivalent (archaeological_restrictions, hospitality_use_feasibility).
with aw as (select id from public.worlds where code='ALIKI'),
gates(code,category,label,is_critical,sort_order) as (values
 ('ownership','LEGAL & PLANNING','Ownership clean and verifiable',true,10),
 ('legal_access','LEGAL & PLANNING','Legal access confirmed',true,20),
 ('buildability','LEGAL & PLANNING','Legal buildability / permitted development path',true,30),
 ('archaeological_restrictions','LEGAL & PLANNING','Archaeological authority restrictions / zone compliance verified',true,40),
 ('protected_area_restrictions','LEGAL & PLANNING','Protected-area / environmental restrictions checked',true,50),
 ('hospitality_use_feasibility','LEGAL & PLANNING','Intended hospitality / commercial use feasibility confirmed',true,60),
 ('water','INFRASTRUCTURE','Water solution viable',false,70),
 ('wastewater','INFRASTRUCTURE','Wastewater solution viable',true,80),
 ('utilities','INFRASTRUCTURE','Electricity / off-grid solution viable',false,90),
 ('emergency_access','ACCESS','Emergency access viable',false,100)
)
insert into public.world_gate_definitions(world_id,code,category,label,is_critical,sort_order)
select aw.id,g.code,g.category,g.label,g.is_critical,g.sort_order
from aw cross join gates g
on conflict (world_id,code) do update set
 category=excluded.category,label=excluded.label,is_critical=excluded.is_critical,sort_order=excluded.sort_order,is_active=true;

commit;
