-- SIDEWORLD V3.2 production Prepare gate. READ ONLY.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;
set local statement_timeout = '60s';
set local lock_timeout = '5s';

do $$
declare
  expected_versions constant text[] := array[
    '202608180001','202608180002','202608180003','202608180004','202608200001','202608210001',
    '202609020001','202609030001','20260912141712','20260912141742','20260912145301',
    '20260913141314','20260913141954','20260917110721','202609190001','20260919100334',
    '202610020001','202610020002','20261004140102'];
  v32_tables constant text[] := array[
    'universe.universes','universe.worlds','universe.themes','universe.world_cities','universe.world_outland_map',
    'geo.countries','geo.cities','geo.locations','geo.location_facts','geo.sources','geo.fact_sources',
    'canon.franchises','canon.series','canon.characters','canon.character_relationships','canon.factions',
    'canon.lore_facts','canon.canon_rules'];
  v_missing text[]; v_extra text[]; v_present text[];
begin
  if current_setting('transaction_read_only') <> 'on' then raise exception 'not read-only'; end if;
  if current_setting('statement_timeout') <> '1min' or current_setting('lock_timeout') <> '5s' then
    raise exception 'timeouts not effective';
  end if;

  if not exists (select 1 from shared.worlds where code='RAFTER')
     or exists (select 1 from shared.worlds where code='RIVERKEEPER') then
    raise exception 'World canon is not production''s: RAFTER expected, RIVERKEEPER unexpected';
  end if;

  select array_agg(e) into v_missing from unnest(expected_versions) e
    where not exists (select 1 from supabase_migrations.schema_migrations m where m.version=e);
  select array_agg(m.version order by m.version) into v_extra from supabase_migrations.schema_migrations m
    where m.version <> all(expected_versions);
  if v_missing is not null or v_extra is not null then
    raise exception 'Ledger differs from expected 19 versions: missing %, unexpected %', v_missing, v_extra;
  end if;
  if (select max(version) from supabase_migrations.schema_migrations) <> '20261004140102' then
    raise exception 'Latest version mismatch';
  end if;

  if to_regclass('universe.nodes') is not null or to_regclass('universe.frontiers') is not null
     or to_regclass('universe.spots') is not null then raise exception 'Legacy universe objects still exist'; end if;
  if exists (select 1 from information_schema.columns where table_schema='passport'
             and (table_name,column_name) in (('journeys','node_id'),('events','node_id'),('events','frontier_id'),('events','spot_id')))
     then raise exception 'Legacy Passport columns still exist'; end if;

  select array_agg(t) into v_present from unnest(v32_tables) t where to_regclass(t) is not null;
  if v_present is not null then raise exception 'V3.2 objects already present: %', v_present; end if;

  if to_regclass('shared.worlds') is null or to_regclass('infrastructure.bases') is null
     or to_regclass('passport.journeys') is null or to_regclass('passport.events') is null
     or to_regclass('shared.activities') is null or to_regclass('land.candidates') is null then
    raise exception 'Preserved OUTLAND table missing';
  end if;
  if not exists (select 1 from pg_constraint c where c.contype='f' and c.conrelid='infrastructure.bases'::regclass and c.confrelid='shared.worlds'::regclass)
     then raise exception 'infrastructure.bases boundary mismatch'; end if;
  if to_regprocedure('universe.set_updated_at()') is null then raise exception 'universe.set_updated_at missing'; end if;
  if not exists (select 1 from pg_trigger where tgname='passport_journeys_set_updated_at' and not tgisinternal
                 and tgrelid='passport.journeys'::regclass and tgfoid='universe.set_updated_at()'::regprocedure)
     then raise exception 'Passport trigger mismatch'; end if;
  if to_regprocedure('public.set_updated_at()') is null then raise exception 'public.set_updated_at missing'; end if;
  if to_regprocedure('gen_random_uuid()') is null then raise exception 'gen_random_uuid unavailable'; end if;

  raise notice 'PRODUCTION V3.2 TARGET VERIFIED: 19 versions, cleanup complete, RAFTER canon, no V3.2 objects, preserved boundaries intact; statement_timeout=1min, lock_timeout=5s';
end $$;
rollback;