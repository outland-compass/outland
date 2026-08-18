-- seed.sql
-- OUTLAND COMPASS v0.1 seed configuration.
-- Safe to run after migrations in local/staging. Review before production.

insert into public.score_dimensions(code,label,sort_order) values
('PLACE','Place',10),
('FEASIBILITY','Feasibility',20),
('ECONOMICS','Economics',30),
('OUTLAND','OUTLAND Fit',40),
('NETWORK','Network Fit',50)
on conflict (code) do update set label=excluded.label, sort_order=excluded.sort_order;

insert into public.worlds(
  code,name,environment,archetype,inner_movement,asset_kind,radar_enabled,
  target_geography,target_area_min_m2,target_area_max_m2,
  target_capital_min_eur,target_capital_max_eur,reunderwrite_above_eur,
  target_profile
) values
('GREENHILL','GREENHILL','Forest','HOME','RETURN','LAND',true,
 'Fruška Gora / Serbia',5000,20000,80000,120000,null,
 '{"priority":{"nature":"VERY_HIGH","privacy":"VERY_HIGH","buildability":"GATE","camper_suitability":"HIGH","frequent_personal_use":"HIGH"}}'),
('LOST_SIGNAL','LOST SIGNAL','Mountain','MYSTERY / SEARCH','FOLLOW','LAND',true,
 'Durmitor / Žabljak / Montenegro',null,null,90000,140000,null,
 '{"priority":{"wilderness":"VERY_HIGH","mountain_view":"HIGH","winter_access":"GATE","buildability":"GATE"}}'),
('NAVIGATOR','NAVIGATOR','Sea','DISCOVERY','SEEK','LAND',true,
 'Žanjice / Luštica / Montenegro',null,null,140000,200000,null,
 '{"priority":{"sea_relationship":"VERY_HIGH","scarcity":"HIGH","buildability":"GATE","utilities_wastewater":"HIGH"}}'),
('LOST_VALLEY','LOST VALLEY','Primeval forest','SILENCE','LISTEN','LAND',true,
 'Sutjeska / Perućica / Bosnia & Herzegovina',10000,50000,50000,80000,null,
 '{"priority":{"wilderness":"VERY_HIGH","privacy":"VERY_HIGH","simple_infrastructure":"HIGH","overbuilding":"AVOID"}}'),
('RIVERKEEPER','RIVERKEEPER','River','GUARDIAN','FLOW','FLOATING',true,
 'Novi Sad / Danube / Dunavac / Ribarsko ostrvo',null,null,60000,70000,80000,
 '{"priority":{"berth_location_right":"GATE","registration":"GATE","commercial_use":"GATE","water_envelope":"GATE","wastewater":"GATE","quiet_water_experience":"VERY_HIGH"}}'),
('WANDERER','WANDERER','Road','FREEDOM','GO','MOBILE',false,
 'Mobile / network-wide',null,null,70000,90000,null,
 '{"priority":{"portfolio_mobility":"VERY_HIGH","scouting":"VERY_HIGH"}}')
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

-- Default dimension weights for every Radar-enabled world.
insert into public.world_dimension_weights(world_id,dimension,weight)
select w.id, x.dimension, x.weight
from public.worlds w
cross join (values
 ('PLACE'::public.score_dimension,0.35::numeric),
 ('FEASIBILITY'::public.score_dimension,0.20::numeric),
 ('ECONOMICS'::public.score_dimension,0.20::numeric),
 ('OUTLAND'::public.score_dimension,0.15::numeric),
 ('NETWORK'::public.score_dimension,0.10::numeric)
) x(dimension,weight)
where w.radar_enabled
on conflict (world_id,dimension) do update set weight=excluded.weight;

-- Shared LAND criteria for GREENHILL / LOST SIGNAL / NAVIGATOR / LOST VALLEY.
with land_worlds as (
  select id from public.worlds where code in ('GREENHILL','LOST_SIGNAL','NAVIGATOR','LOST_VALLEY')
),
criteria(dimension,code,label,item_weight,sort_order) as (values
 ('PLACE'::public.score_dimension,'natural_beauty','Natural beauty / immersion',1.3,10),
 ('PLACE'::public.score_dimension,'privacy','Privacy',1.2,20),
 ('PLACE'::public.score_dimension,'silence','Silence / low noise',1.0,30),
 ('PLACE'::public.score_dimension,'view_character','View / landscape character',1.0,40),
 ('PLACE'::public.score_dimension,'outdoor_access','Outdoor activity access',0.8,50),

 ('FEASIBILITY'::public.score_dimension,'legal_buildability','Legal / buildability confidence',1.4,10),
 ('FEASIBILITY'::public.score_dimension,'vehicle_access','Vehicle / practical access',1.0,20),
 ('FEASIBILITY'::public.score_dimension,'utilities','Utilities feasibility',1.0,30),
 ('FEASIBILITY'::public.score_dimension,'camper_suitability','Camper suitability',0.8,40),
 ('FEASIBILITY'::public.score_dimension,'development_fit','Development fit',1.0,50),

 ('ECONOMICS'::public.score_dimension,'price_attractiveness','Purchase-price attractiveness',1.3,10),
 ('ECONOMICS'::public.score_dimension,'hidden_capex','Hidden CAPEX / minimum usable state',1.1,20),
 ('ECONOMICS'::public.score_dimension,'rental_potential','Rental potential',1.0,30),
 ('ECONOMICS'::public.score_dimension,'seasonality','Seasonality resilience',0.8,40),
 ('ECONOMICS'::public.score_dimension,'appreciation_exit','Appreciation / exit potential',0.8,50),

 ('OUTLAND'::public.score_dimension,'world_identity','World identity fit',1.3,10),
 ('OUTLAND'::public.score_dimension,'story_potential','Story potential',1.0,20),
 ('OUTLAND'::public.score_dimension,'mystery_potential','Mystery potential',0.8,30),
 ('OUTLAND'::public.score_dimension,'emotional_character','Emotional character',1.2,40),
 ('OUTLAND'::public.score_dimension,'lifestyle_value','Personal / lifestyle value',0.7,50),

 ('NETWORK'::public.score_dimension,'portfolio_differentiation','Portfolio differentiation',1.1,10),
 ('NETWORK'::public.score_dimension,'seasonal_complementarity','Seasonal complementarity',1.0,20),
 ('NETWORK'::public.score_dimension,'cross_sell','Cross-world travel / cross-sell',0.8,30),
 ('NETWORK'::public.score_dimension,'operational_synergy','Shared operations / equipment synergy',0.8,40),
 ('NETWORK'::public.score_dimension,'network_role','Strategic network role',1.2,50)
)
insert into public.world_score_criteria(world_id,dimension,code,label,item_weight,sort_order)
select lw.id,c.dimension,c.code,c.label,c.item_weight,c.sort_order
from land_worlds lw cross join criteria c
on conflict (world_id,code) do update set
 dimension=excluded.dimension,label=excluded.label,item_weight=excluded.item_weight,sort_order=excluded.sort_order,is_active=true;

-- RIVERKEEPER criteria.
with rw as (select id from public.worlds where code='RIVERKEEPER'),
criteria(dimension,code,label,item_weight,sort_order) as (values
 ('PLACE'::public.score_dimension,'water_experience','Water / reed / river experience quality',1.4,10),
 ('PLACE'::public.score_dimension,'quiet_privacy','Quiet / privacy from neighboring activity',1.4,20),
 ('PLACE'::public.score_dimension,'view_orientation','Water view / orientation',1.0,30),
 ('PLACE'::public.score_dimension,'paddle_launch','Safe kayak / SUP relationship',0.8,40),

 ('FEASIBILITY'::public.score_dimension,'berth_right','Berth / location-right confidence',1.5,10),
 ('FEASIBILITY'::public.score_dimension,'registration_commercial','Registration / commercial-use confidence',1.5,20),
 ('FEASIBILITY'::public.score_dimension,'water_resilience','High / low-water resilience',1.3,30),
 ('FEASIBILITY'::public.score_dimension,'marine_safety','Marine / mooring / access safety',1.2,40),
 ('FEASIBILITY'::public.score_dimension,'wastewater','Wastewater feasibility',1.3,50),
 ('FEASIBILITY'::public.score_dimension,'utilities','Power / water / connectivity',0.8,60),

 ('ECONOMICS'::public.score_dimension,'price_attractiveness','Purchase-price attractiveness',1.3,10),
 ('ECONOMICS'::public.score_dimension,'transformation_capex','Transformation / safety CAPEX',1.2,20),
 ('ECONOMICS'::public.score_dimension,'adr_potential','Premium ADR potential',1.0,30),
 ('ECONOMICS'::public.score_dimension,'operating_costs','Berth / marine / servicing cost profile',1.0,40),
 ('ECONOMICS'::public.score_dimension,'fast_to_bookable','Time / capital to first bookable state',1.0,50),

 ('OUTLAND'::public.score_dimension,'world_identity','RIVERKEEPER identity fit',1.4,10),
 ('OUTLAND'::public.score_dimension,'story_potential','The Last Riverkeeper story potential',1.0,20),
 ('OUTLAND'::public.score_dimension,'mystery_potential','Mystery / Return the Mark potential',0.8,30),
 ('OUTLAND'::public.score_dimension,'water_room','Water Room / deck potential',1.1,40),
 ('OUTLAND'::public.score_dimension,'premium_microretreat','Premium 2-person micro-retreat fit',1.2,50),

 ('NETWORK'::public.score_dimension,'early_lab','Early COMPASS/SENSE operations-lab value',1.3,10),
 ('NETWORK'::public.score_dimension,'novi_sad_proximity','Low-friction Novi Sad proximity',1.2,20),
 ('NETWORK'::public.score_dimension,'portfolio_differentiation','Portfolio differentiation',1.1,30),
 ('NETWORK'::public.score_dimension,'content_brand_value','Content / brand value',0.9,40),
 ('NETWORK'::public.score_dimension,'cross_sell','Cross-world travel / cross-sell',0.8,50)
)
insert into public.world_score_criteria(world_id,dimension,code,label,item_weight,sort_order)
select rw.id,c.dimension,c.code,c.label,c.item_weight,c.sort_order
from rw cross join criteria c
on conflict (world_id,code) do update set
 dimension=excluded.dimension,label=excluded.label,item_weight=excluded.item_weight,sort_order=excluded.sort_order,is_active=true;

-- LAND gate template.
with land_worlds as (
  select id from public.worlds where code in ('GREENHILL','LOST_SIGNAL','NAVIGATOR','LOST_VALLEY')
),
gates(code,category,label,is_critical,sort_order) as (values
 ('ownership','LEGAL & PLANNING','Ownership clean and verifiable',true,10),
 ('parcel_identified','LEGAL & PLANNING','Parcel identified / boundaries understood',true,20),
 ('legal_access','LEGAL & PLANNING','Legal access confirmed',true,30),
 ('zoning_use','LEGAL & PLANNING','Zoning / intended use confirmed',true,40),
 ('buildability','LEGAL & PLANNING','Buildability / construction path verified',true,50),
 ('protected_restrictions','LEGAL & PLANNING','Protected-area / restrictions checked',false,60),
 ('vehicle_access','ACCESS','Normal vehicle access viable',false,70),
 ('utilities','INFRASTRUCTURE','Electricity / off-grid plan viable',false,80),
 ('water','INFRASTRUCTURE','Water source viable',false,90),
 ('wastewater','INFRASTRUCTURE','Wastewater solution viable',true,100)
)
insert into public.world_gate_definitions(world_id,code,category,label,is_critical,sort_order)
select lw.id,g.code,g.category,g.label,g.is_critical,g.sort_order
from land_worlds lw cross join gates g
on conflict (world_id,code) do update set
 category=excluded.category,label=excluded.label,is_critical=excluded.is_critical,sort_order=excluded.sort_order,is_active=true;

-- RIVERKEEPER gate template.
with rw as (select id from public.worlds where code='RIVERKEEPER'),
gates(code,category,label,is_critical,sort_order) as (values
 ('floating_ownership','LEGAL & CONTROL','Floating-object ownership clean and verifiable',true,10),
 ('registration','LEGAL & CONTROL','Registration status / registrability verified',true,20),
 ('berth_right','LEGAL & CONTROL','Defensible written berth / location right',true,30),
 ('commercial_use','LEGAL & CONTROL','Commercial hospitality use verified',true,40),
 ('water_envelope','WATER ENVELOPE','High / low-water operating envelope acceptable',true,50),
 ('moorings','FLOATING ASSET','Moorings / float condition / structural safety acceptable',true,60),
 ('shore_access','SHORE ACCESS','Reliable shore / gangway / service access',true,70),
 ('emergency_access','SHORE ACCESS','Emergency access acceptable under extremes',true,80),
 ('shore_power','UTILITIES & WASTE','Safe shore power / backup path understood',false,90),
 ('fresh_water','UTILITIES & WASTE','Fresh-water solution viable',false,100),
 ('wastewater','UTILITIES & WASTE','Wastewater / black-water solution acceptable',true,110),
 ('quiet_privacy','EXPERIENCE FIT','Quiet / privacy from neighboring splav activity',false,120)
)
insert into public.world_gate_definitions(world_id,code,category,label,is_critical,sort_order)
select rw.id,g.code,g.category,g.label,g.is_critical,g.sort_order
from rw cross join gates g
on conflict (world_id,code) do update set
 category=excluded.category,label=excluded.label,is_critical=excluded.is_critical,sort_order=excluded.sort_order,is_active=true;
