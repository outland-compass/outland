-- 202608200001_bootstrap_reference_data.sql
-- Bootstrap the score-dimension reference/config data that later migrations
-- (starting with 202608210001_outland_strategy_update.sql) assume already exists,
-- so the migration chain is self-contained on a completely empty database.
-- This is stable reference data only, not application/demo seed data.

insert into public.score_dimensions(code,label,sort_order) values
('PLACE','Place',10),
('FEASIBILITY','Feasibility',20),
('ECONOMICS','Economics',30),
('OUTLAND','OUTLAND Fit',40),
('NETWORK','Network Fit',50)
on conflict (code) do update set label=excluded.label, sort_order=excluded.sort_order;
