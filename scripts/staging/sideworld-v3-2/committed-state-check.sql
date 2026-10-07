-- SIDEWORLD V3.2: verify the COMMITTED V3.2 schema state, before any ledger repair. READ ONLY.
-- Used by deploy-staging-v3-2.ps1 right after the atomic apply commits (Execute) and by -Mode CompleteLedger.
-- Passes only if: exactly the 18 expected tables exist, the exact 25 expected FKs are present, the expected
-- updated_at triggers exist, RLS is on, there are no policies or API-role privileges, all tables are empty,
-- OUTLAND FKs are untouched, and the ledger holds the
-- 19-version baseline plus a subset of the four V3.2 versions (nothing else). Prints which V3.2 versions are
-- missing from the ledger: the caller repairs ONLY those. Never creates or alters schema.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;
do $$
declare
  baseline constant text[] := array[
    '202608180001','202608180002','202608180003','202608180004','202608200001','202608210001',
    '202609020001','202609030001','20260912141712','20260912141742','20260912145301',
    '20260913141314','20260913141954','20260917110721','202609190001','20260919100334',
    '202610020001','202610020002','20261004140102'];
  v32 constant text[] := array['202610060001','202610060002','202610060003','202610060004'];
  v32_tables constant text[] := array[
    'universe.universes','universe.worlds','universe.themes','universe.world_cities','universe.world_outland_map',
    'geo.countries','geo.cities','geo.locations','geo.location_facts','geo.sources','geo.fact_sources',
    'canon.franchises','canon.series','canon.characters','canon.character_relationships','canon.factions',
    'canon.lore_facts','canon.canon_rules'];
  expected_fks constant text :=
    'canon.canon_rules->canon.characters,canon.canon_rules->canon.franchises,canon.canon_rules->canon.series,'
    'canon.character_relationships->canon.characters,canon.character_relationships->canon.characters,'
    'canon.character_relationships->canon.franchises,canon.characters->canon.franchises,canon.factions->canon.franchises,'
    'canon.franchises->universe.universes,canon.lore_facts->canon.franchises,canon.lore_facts->canon.series,'
    'canon.series->canon.franchises,canon.series->universe.themes,geo.cities->geo.countries,'
    'geo.fact_sources->geo.location_facts,geo.fact_sources->geo.sources,geo.location_facts->geo.cities,'
    'geo.location_facts->geo.locations,geo.locations->geo.cities,universe.themes->universe.universes,'
    'universe.world_cities->geo.cities,universe.world_cities->universe.worlds,universe.world_outland_map->shared.worlds,'
    'universe.world_outland_map->universe.worlds,universe.worlds->universe.universes';
  v_fks text; v_missing text[]; v_bad text[]; v_recorded text[]; v_absent text[]; t text; n bigint; r text;
begin
  -- Schema: exactly the 18 expected tables, exact FKs, triggers, RLS/private/empty.
  select array_agg(x) into v_missing from unnest(v32_tables) x where to_regclass(x) is null;
  if v_missing is not null then raise exception 'COMMITTED STATE MISMATCH: missing tables %', v_missing; end if;
  if (select count(*) from pg_class c where c.relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)
      and c.relkind in ('r','p','v','m','f')) <> 18 then
    raise exception 'COMMITTED STATE MISMATCH: universe/geo/canon contain relations other than the 18 tables'; end if;
  select string_agg(src || '->' || dst, ',' order by src || '->' || dst) into v_fks from (
    select (select n.nspname || '.' || c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where c.oid = co.conrelid) as src,
           (select n.nspname || '.' || c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace where c.oid = co.confrelid) as dst
    from pg_constraint co where co.contype = 'f'
      and co.conrelid in (select oid from pg_class where relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace))) f;
  if v_fks is distinct from expected_fks then
    raise exception 'COMMITTED STATE MISMATCH: foreign keys differ: %', v_fks; end if;
  if (select count(*) from pg_trigger tg join pg_class c on c.oid = tg.tgrelid
      where c.relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)
        and not tg.tgisinternal and tg.tgfoid = 'public.set_updated_at()'::regprocedure) <> 13 then
    raise exception 'COMMITTED STATE MISMATCH: expected 13 V3.2 updated_at triggers'; end if;
  if exists (select 1 from pg_policy p join pg_class c on c.oid = p.polrelid
             where c.relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)) then
    raise exception 'COMMITTED STATE MISMATCH: unexpected RLS policies exist'; end if;
  if exists (select 1 from information_schema.role_table_grants
             where table_schema in ('universe','geo','canon') and grantee in ('PUBLIC','anon','authenticated','service_role')) then
    raise exception 'COMMITTED STATE MISMATCH: unexpected table grant exists'; end if;
  select array_agg(x) into v_bad from unnest(v32_tables) x where not (select relrowsecurity from pg_class where oid = x::regclass);
  if v_bad is not null then raise exception 'COMMITTED STATE MISMATCH: RLS disabled on %', v_bad; end if;
  foreach r in array array['anon','authenticated','service_role'] loop
    if has_schema_privilege(r, 'universe', 'USAGE') or has_schema_privilege(r, 'geo', 'USAGE') or has_schema_privilege(r, 'canon', 'USAGE') then
      raise exception 'COMMITTED STATE MISMATCH: % has USAGE on a V3.2 schema', r; end if;
    foreach t in array v32_tables loop
      if has_table_privilege(r, t, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER') then
        raise exception 'COMMITTED STATE MISMATCH: % has a privilege on %', r, t; end if;
    end loop;
  end loop;
  foreach t in array v32_tables loop
    execute format('select count(*) from %s', t) into n;
    if n <> 0 then raise exception 'COMMITTED STATE MISMATCH: % has % row(s) (expected empty foundation)', t, n; end if;
  end loop;
  if exists (select 1 from pg_constraint c where c.contype = 'f'
             and (select relnamespace from pg_class where oid = c.conrelid) in ('land'::regnamespace, 'shared'::regnamespace, 'infrastructure'::regnamespace, 'passport'::regnamespace)
             and (select relnamespace from pg_class where oid = c.confrelid) in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)) then
    raise exception 'COMMITTED STATE MISMATCH: an OUTLAND table references a V3.2 table'; end if;

  -- Ledger: the baseline intact; only V3.2 versions beyond it; report which V3.2 versions are missing.
  if exists (select 1 from unnest(baseline) e where not exists (select 1 from supabase_migrations.schema_migrations m where m.version = e))
     or exists (select 1 from supabase_migrations.schema_migrations m where m.version <> all (baseline || v32))
     or (select count(*) from supabase_migrations.schema_migrations) <> (select count(distinct version) from supabase_migrations.schema_migrations) then
    raise exception 'LEDGER MISMATCH: baseline incomplete, duplicate or unexpected versions present'; end if;
  select array_agg(v order by v) into v_recorded from unnest(v32) v where exists (select 1 from supabase_migrations.schema_migrations m where m.version = v);
  select array_agg(v order by v) into v_absent from unnest(v32) v where not exists (select 1 from supabase_migrations.schema_migrations m where m.version = v);
  raise notice 'V3.2 COMMITTED STATE VERIFIED: 18 expected tables, 25 exact FKs, 13 updated_at triggers, RLS on 18, no policies/grants, private, empty; ledger recorded=% missing=%',
    coalesce(array_to_string(v_recorded, ' '), '-'), coalesce(array_to_string(v_absent, ' '), '-');
  raise notice 'MISSING_LEDGER_VERSIONS=%', coalesce(array_to_string(v_absent, ' '), '');
end $$;
rollback;
