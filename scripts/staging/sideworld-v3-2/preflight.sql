-- SIDEWORLD V3.2 staging rehearsal: pre-apply target gate. READ ONLY: changes nothing.
-- Any failure = STOP; nothing has been changed. The operator script additionally requires the exact staging
-- pooler URL (user postgres.clgpxvyflycudzhdzjlv) and byte-identical fingerprints against the fresh backup.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;
-- Timeout probe: the apply step sets these the same way (in-session SET, which the pooler cannot drop).
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
  v_extra text[]; v_missing text[]; v_present text[]; v_universe text[];
begin
  if current_setting('transaction_read_only') <> 'on' then raise exception 'not read-only'; end if;
  if current_setting('statement_timeout') <> '1min' or current_setting('lock_timeout') <> '5s' then
    raise exception 'In-session timeouts not effective (statement_timeout=%, lock_timeout=%): STOP',
      current_setting('statement_timeout'), current_setting('lock_timeout');
  end if;

  -- 1. Staging identity (besides the exact pooler URL): staging keeps the pre-#27 world canon
  --    (RIVERKEEPER, no RAFTER); production has RAFTER. Either mismatch = wrong or changed target.
  if not exists (select 1 from shared.worlds where code = 'RIVERKEEPER')
     or exists (select 1 from shared.worlds where code = 'RAFTER') then
    raise exception 'World canon is not staging''s (RIVERKEEPER expected, RAFTER unexpected): STOP';
  end if;

  -- 2. Ledger: exactly the 19 versions, latest = Legacy Universe V0 cleanup; no V3.2 version yet.
  select array_agg(e) into v_missing from unnest(expected_versions) e
   where not exists (select 1 from supabase_migrations.schema_migrations m where m.version = e);
  select array_agg(m.version order by m.version) into v_extra from supabase_migrations.schema_migrations m
   where m.version <> all (expected_versions);
  if v_missing is not null or v_extra is not null then
    raise exception 'Ledger differs from the 19 expected versions: missing %, unexpected %: STOP', v_missing, v_extra;
  end if;
  if (select max(version) from supabase_migrations.schema_migrations) <> '20261004140102' then
    raise exception 'Latest version is not 20261004140102: STOP';
  end if;

  -- 3. Legacy Universe V0 cleanup complete.
  if to_regclass('universe.nodes') is not null or to_regclass('universe.frontiers') is not null
     or to_regclass('universe.spots') is not null then
    raise exception 'Legacy universe tables still exist: STOP';
  end if;
  if exists (select 1 from information_schema.columns where table_schema = 'passport'
             and (table_name, column_name) in (('journeys','node_id'),('events','node_id'),('events','frontier_id'),('events','spot_id'))) then
    raise exception 'Legacy Passport columns still exist: STOP';
  end if;

  -- 4. Preserved OUTLAND objects and the dependencies the V3.2 migrations rely on.
  if to_regclass('shared.worlds') is null or to_regclass('infrastructure.bases') is null
     or to_regclass('infrastructure.base_legacy_migration_audit') is null or to_regclass('passport.journeys') is null
     or to_regclass('passport.events') is null or to_regclass('shared.activities') is null
     or to_regclass('land.candidates') is null then
    raise exception 'A preserved OUTLAND table is missing: STOP';
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'shared.worlds'::regclass and contype in ('p','u')
                 and conkey = array[(select attnum from pg_attribute where attrelid = 'shared.worlds'::regclass and attname = 'id')]) then
    raise exception 'shared.worlds(id) is not unique: the world_outland_map FK would fail: STOP';
  end if;
  if not exists (select 1 from pg_constraint c where c.contype = 'f' and c.conrelid = 'infrastructure.bases'::regclass
                 and c.confrelid = 'shared.worlds'::regclass) then
    raise exception 'infrastructure.bases no longer references shared.worlds: STOP';
  end if;
  if to_regprocedure('universe.set_updated_at()') is null then
    raise exception 'universe.set_updated_at() missing: STOP'; end if;
  if not exists (select 1 from pg_trigger where tgname = 'passport_journeys_set_updated_at'
                 and tgrelid = 'passport.journeys'::regclass and tgfoid = 'universe.set_updated_at()'::regprocedure) then
    raise exception 'Passport trigger no longer uses universe.set_updated_at(): STOP'; end if;
  if to_regprocedure('public.set_updated_at()') is null
     or (select prorettype from pg_proc where oid = 'public.set_updated_at()'::regprocedure) <> 'trigger'::regtype then
    raise exception 'public.set_updated_at() trigger function (used by all V3.2 tables) missing: STOP'; end if;
  if to_regprocedure('gen_random_uuid()') is null then
    raise exception 'gen_random_uuid() not available: STOP'; end if;

  -- 5. No V3.2 objects yet; universe holds only the retained helper (no drift that would break the migrations).
  select array_agg(t) into v_present from unnest(v32_tables) t where to_regclass(t) is not null;
  if v_present is not null then raise exception 'V3.2 tables already exist: %: STOP', v_present; end if;
  if to_regnamespace('geo') is not null or to_regnamespace('canon') is not null then
    raise exception 'Schema geo or canon already exists: STOP'; end if;
  select array_agg(c.relkind::text || ':' || c.relname) into v_universe from pg_class c where c.relnamespace = 'universe'::regnamespace;
  if v_universe is not null then raise exception 'Unexpected relations in schema universe: %: STOP', v_universe; end if;
  if (select count(*) from pg_proc where pronamespace = 'universe'::regnamespace) <> 1
     or exists (select 1 from pg_type t where t.typnamespace = 'universe'::regnamespace) then
    raise exception 'Schema universe contains objects other than set_updated_at(): STOP'; end if;
  if exists (select 1 from pg_trigger where tgname in ('universe_universes_set_updated_at','universe_worlds_set_updated_at','universe_themes_set_updated_at')) then
    raise exception 'V3.2 trigger names already in use: STOP'; end if;

  raise notice 'STAGING V3.2 TARGET VERIFIED: 19 versions (latest 20261004140102), legacy cleanup complete, % world(s), % candidate(s), % base(s), % audit row(s), % journey(s), % event(s), % activit(ies); statement_timeout=%, lock_timeout=%',
    (select count(*) from shared.worlds), (select count(*) from land.candidates), (select count(*) from infrastructure.bases),
    (select count(*) from infrastructure.base_legacy_migration_audit), (select count(*) from passport.journeys),
    (select count(*) from passport.events), (select count(*) from shared.activities),
    current_setting('statement_timeout'), current_setting('lock_timeout');
end $$;
rollback;
