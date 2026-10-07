-- SIDEWORLD V3.2 staging rehearsal: post-apply validation (after the ledger is complete). READ ONLY.
-- Preserved-data equality is checked separately (fingerprints.sql vs the backup baseline), and Compass API
-- exposure is checked by the operator script's PostgREST probe.
\set ON_ERROR_STOP 1
-- 1. The committed schema: exact 18 tables / 25 FKs / trigger-policy-privilege guards, RLS, private, empty.
\ir committed-state-check.sql
-- 2. Ledger complete and OUTLAND boundaries intact.
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;
do $$
declare
  v32_versions constant text[] := array['202610060001','202610060002','202610060003','202610060004'];
begin
  if (select count(*) from supabase_migrations.schema_migrations) <> 23
     or (select count(distinct version) from supabase_migrations.schema_migrations) <> 23
     or (select count(*) from supabase_migrations.schema_migrations where version = any (v32_versions)) <> 4
     or (select max(version) from supabase_migrations.schema_migrations) <> '202610060004'
     or (select count(*) from supabase_migrations.schema_migrations where version > '20261004140102') <> 4 then
    raise exception 'Ledger is not 23 versions with each V3.2 version exactly once on top of 20261004140102'; end if;
  if exists (select 1 from pg_policy p join pg_class c on c.oid = p.polrelid
             where c.relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)) then
    raise exception 'Unexpected RLS policies on V3.2 tables'; end if;
  if exists (select 1 from information_schema.role_table_grants
             where table_schema in ('universe','geo','canon') and grantee in ('PUBLIC','anon','authenticated','service_role')) then
    raise exception 'Unexpected table grant on a V3.2 schema'; end if;
  if not exists (select 1 from pg_constraint c where c.contype = 'f' and c.conrelid = 'infrastructure.bases'::regclass
                 and c.confrelid = 'shared.worlds'::regclass) then
    raise exception 'infrastructure.bases no longer references shared.worlds'; end if;
  if exists (select 1 from pg_constraint c where c.contype = 'f'
             and (select relnamespace from pg_class where oid = c.conrelid) = 'land'::regnamespace
             and c.confrelid = 'universe.worlds'::regclass) then
    raise exception 'A land table references universe.worlds'; end if;
  if not exists (select 1 from pg_constraint c where c.contype = 'f' and c.conrelid = 'universe.world_outland_map'::regclass
                 and c.confrelid = 'shared.worlds'::regclass and c.confdeltype = 'r') then
    raise exception 'universe.world_outland_map does not reference shared.worlds with ON DELETE RESTRICT'; end if;
  if (select count(*) from pg_constraint c where c.contype = 'f' and c.confrelid = 'shared.worlds'::regclass
      and (select relnamespace from pg_class where oid = c.conrelid) in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)) <> 1 then
    raise exception 'Expected exactly one V3.2 FK to shared.worlds (world_outland_map)'; end if;
  if to_regnamespace('places') is not null and to_regclass('places.base') is not null then
    raise exception 'Competing places.base exists'; end if;
  if to_regprocedure('universe.set_updated_at()') is null
     or not exists (select 1 from pg_trigger where tgname = 'passport_journeys_set_updated_at' and not tgisinternal
                    and tgrelid = 'passport.journeys'::regclass and tgfoid = 'universe.set_updated_at()'::regprocedure) then
    raise exception 'universe.set_updated_at() or the Passport trigger is missing'; end if;
  if (select count(*) from pg_trigger tg join pg_class c on c.oid = tg.tgrelid
      where c.relnamespace in ('universe'::regnamespace, 'geo'::regnamespace, 'canon'::regnamespace)
        and not tg.tgisinternal and tg.tgfoid = 'public.set_updated_at()'::regprocedure) <> 13 then
    raise exception 'Expected 13 V3.2 updated_at triggers on public.set_updated_at()'; end if;
  raise notice 'STAGING V3.2 POST-APPLY VALIDATION PASSED: 23 versions, 18 private empty RLS tables with pinned structure, explicit shared.worlds bridge only, Passport helper retained';
end $$;
rollback;
