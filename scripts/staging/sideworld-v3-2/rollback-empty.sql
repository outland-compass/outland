-- SIDEWORLD V3.2 staging rehearsal: rollback for the EMPTY state only. NOT run by any script automatically.
-- Run only after separate written approval, as ONE transaction:
--   psql -X -1 -v ON_ERROR_STOP=1 -c "set lock_timeout = '5s'" -c "set statement_timeout = '60s'" -f rollback-empty.sql
-- (with -1, psql wraps the -c SETs and the file in one BEGIN ... COMMIT; the SETs apply to the drops.) Then reconcile the ledger (see the plan).
-- Drops ONLY the 18 V3.2 tables and the geo/canon schemas, in reverse dependency order, with RESTRICT (no CASCADE).
-- Refuses to run if ANY V3.2 table has rows, if anything else lives in geo/canon/universe, or if any object
-- outside V3.2 depends on them. Keeps schema universe and universe.set_updated_at() (Passport trigger), and
-- restores the post-cleanup universe schema comment. Data loss: none by construction (all tables empty).
\set ON_ERROR_STOP 1
do $guard$
declare
  v32_tables constant text[] := array[
    'universe.universes','universe.worlds','universe.themes','universe.world_cities','universe.world_outland_map',
    'geo.countries','geo.cities','geo.locations','geo.location_facts','geo.sources','geo.fact_sources',
    'canon.franchises','canon.series','canon.characters','canon.character_relationships','canon.factions',
    'canon.lore_facts','canon.canon_rules'];
  t text; n bigint;
begin
  foreach t in array v32_tables loop
    if to_regclass(t) is null then raise exception 'Expected V3.2 table % missing: STOP (partial state - review manually)', t; end if;
  end loop;
  -- Lock everything first so no row can appear between the emptiness check and the drop.
  execute 'lock table ' || array_to_string(v32_tables, ', ') || ' in access exclusive mode';
  foreach t in array v32_tables loop
    execute format('select count(*) from %s', t) into n;
    if n <> 0 then raise exception 'V3.2 table % has % row(s): STOP - not an empty-state rollback (data would be lost)', t, n; end if;
  end loop;
  if (select count(*) from pg_class c where c.relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)
      and c.relkind in ('r','p','v','m','f')) <> 18 then
    raise exception 'universe/geo/canon contain relations other than the 18 V3.2 tables: STOP'; end if;
  if exists (select 1 from pg_proc where pronamespace in ('geo'::regnamespace, 'canon'::regnamespace))
     or (select count(*) from pg_proc where pronamespace = 'universe'::regnamespace) <> 1 then
    raise exception 'Unexpected functions in universe/geo/canon: STOP'; end if;
  if exists (select 1 from pg_constraint c where c.contype = 'f'
             and c.confrelid in (select oid from pg_class where relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace))
             and (select relnamespace from pg_class where oid = c.conrelid) not in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)) then
    raise exception 'An object outside V3.2 references a V3.2 table: STOP'; end if;
  if exists (select 1 from pg_depend d join pg_rewrite rw on rw.oid = d.objid
             where d.classid = 'pg_rewrite'::regclass
               and d.refobjid in (select oid from pg_class where relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace))
               and rw.ev_class not in (select oid from pg_class where relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace))) then
    raise exception 'A view depends on a V3.2 table: STOP'; end if;
end
$guard$;

-- canon (depends on universe.universes/themes)
drop table canon.canon_rules restrict;
drop table canon.lore_facts restrict;
drop table canon.factions restrict;
drop table canon.character_relationships restrict;
drop table canon.characters restrict;
drop table canon.series restrict;
drop table canon.franchises restrict;
drop schema canon restrict;
-- universe mapping (depends on universe.worlds, geo.cities, shared.worlds)
drop table universe.world_outland_map restrict;
drop table universe.world_cities restrict;
-- geo
drop table geo.fact_sources restrict;
drop table geo.sources restrict;
drop table geo.location_facts restrict;
drop table geo.locations restrict;
drop table geo.cities restrict;
drop table geo.countries restrict;
drop schema geo restrict;
-- universe foundation (schema and set_updated_at() are kept)
drop table universe.themes restrict;
drop table universe.worlds restrict;
drop table universe.universes restrict;
comment on schema universe is 'Legacy OUTLAND V0 tables retired; set_updated_at remains for Passport. Not a Universe registry.';

do $done$
begin
  if to_regnamespace('geo') is not null or to_regnamespace('canon') is not null
     or exists (select 1 from pg_class where relnamespace = 'universe'::regnamespace)
     or to_regprocedure('universe.set_updated_at()') is null
     or not exists (select 1 from pg_trigger where tgname = 'passport_journeys_set_updated_at'
                    and tgfoid = 'universe.set_updated_at()'::regprocedure) then
    raise exception 'Post-rollback state unexpected: STOP (transaction rolls back)'; end if;
  raise notice 'V3.2 EMPTY-STATE ROLLBACK DONE (uncommitted until psql -1 commits): geo/canon and 18 tables dropped; universe.set_updated_at + Passport trigger kept';
end
$done$;
