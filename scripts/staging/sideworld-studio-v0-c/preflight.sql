-- SIDEWORLD Studio V0-C staging preflight. READ ONLY.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;

do $verify$
declare
  expected_versions constant text[] := array[
    '202608180001','202608180002','202608180003','202608180004','202608200001','202608210001',
    '202609020001','202609030001','20260912141712','20260912141742','20260912145301',
    '20260913141314','20260913141954','20260917110721','202609190001','20260919100334',
    '202610020001','202610020002','20261004140102',
    '202610060001','202610060002','202610060003','202610060004'
  ];
  v_missing text[];
  v_extra text[];
begin
  if current_setting('transaction_read_only') <> 'on' then raise exception 'preflight is not read-only'; end if;
  select array_agg(e order by e) into v_missing from unnest(expected_versions) e
   where not exists (select 1 from supabase_migrations.schema_migrations m where m.version=e);
  select array_agg(m.version order by m.version) into v_extra from supabase_migrations.schema_migrations m
   where m.version <> all(expected_versions);
  if v_missing is not null or v_extra is not null then
    raise exception 'Expected exact 23-version V3.2 baseline. Missing %, unexpected %', v_missing, v_extra;
  end if;
  if (select max(version) from supabase_migrations.schema_migrations) <> '202610060004' then
    raise exception 'Latest migration is not 202610060004';
  end if;
  if to_regclass('universe.universes') is null or to_regclass('geo.cities') is null or to_regclass('canon.franchises') is null then
    raise exception 'V3.2 foundation is incomplete';
  end if;
  if to_regprocedure('public.sideworld_studio_read_model(text)') is not null then
    raise exception 'Studio V0-C read boundary already exists';
  end if;
  if has_schema_privilege('anon','universe','USAGE')
     or has_schema_privilege('authenticated','universe','USAGE')
     or has_schema_privilege('service_role','universe','USAGE')
     or has_schema_privilege('anon','geo','USAGE')
     or has_schema_privilege('authenticated','geo','USAGE')
     or has_schema_privilege('service_role','geo','USAGE')
     or has_schema_privilege('anon','canon','USAGE')
     or has_schema_privilege('authenticated','canon','USAGE')
     or has_schema_privilege('service_role','canon','USAGE') then
    raise exception 'A private SIDEWORLD schema has gained API-role USAGE';
  end if;
  raise notice 'STUDIO V0-C STAGING TARGET VERIFIED: exact 23-version V3.2 baseline, private schemas intact, RPC absent';
end
$verify$;

rollback;
