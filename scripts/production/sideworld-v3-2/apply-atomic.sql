-- SIDEWORLD V3.2 production deployment: the ONLY apply path. One outer transaction for all four migrations.
-- Run ONLY via deploy-production-v3-2.ps1 (Execute): psql -X -1 -v ON_ERROR_STOP=1 -f apply-atomic.sql
-- psql -1 issues BEGIN before and COMMIT after this file; any error aborts the whole transaction, so either all
-- four migration bodies commit together or nothing does. The four wrapperless migration files (PR #35) are
-- mounted read-only at /m from the pinned checkout; the operator script verified their git blobs.
-- The migration ledger is NOT touched here: versions are recorded only AFTER this transaction committed
-- (migration repair --status applied, one version at a time; see the rehearsal plan, "ledger recording").
\set ON_ERROR_STOP 1
set local statement_timeout = '60s';
set local lock_timeout = '5s';
do $guard$
declare
  expected_versions constant text[] := array[
    '202608180001','202608180002','202608180003','202608180004','202608200001','202608210001',
    '202609020001','202609030001','20260912141712','20260912141742','20260912145301',
    '20260913141314','20260913141954','20260917110721','202609190001','20260919100334',
    '202610020001','202610020002','20261004140102'];
begin
  if current_setting('statement_timeout') <> '1min' or current_setting('lock_timeout') <> '5s' then
    raise exception 'Timeouts not effective (statement_timeout=%, lock_timeout=%): STOP',
      current_setting('statement_timeout'), current_setting('lock_timeout'); end if;
  if current_setting('transaction_read_only') = 'on' then raise exception 'Read-only session: STOP'; end if;
  -- Exactly the 19-version baseline, nothing more, nothing missing.
  if (select count(*) from supabase_migrations.schema_migrations) <> 19
     or exists (select 1 from unnest(expected_versions) e
                where not exists (select 1 from supabase_migrations.schema_migrations m where m.version = e))
     or exists (select 1 from supabase_migrations.schema_migrations m where m.version <> all (expected_versions)) then
    raise exception 'Ledger is not exactly the 19-version baseline: STOP'; end if;
  if to_regnamespace('geo') is not null or to_regnamespace('canon') is not null
     or exists (select 1 from pg_class where relnamespace = 'universe'::regnamespace) then
    raise exception 'V3.2 objects already exist: STOP'; end if;
  if to_regprocedure('universe.set_updated_at()') is null or to_regprocedure('public.set_updated_at()') is null then
    raise exception 'Required set_updated_at() helper missing: STOP'; end if;
end
$guard$;
\i /m/202610060001_sideworld_universe_foundation.sql
\i /m/202610060002_sideworld_geo_foundation.sql
\i /m/202610060003_sideworld_universe_mapping.sql
\i /m/202610060004_sideworld_canon_foundation.sql
do $done$
begin
  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where c.relkind = 'r' and n.nspname in ('universe','geo','canon')) <> 18 then
    raise exception 'Expected 18 V3.2 tables before commit: STOP (transaction rolls back)'; end if;
  if (select count(*) from supabase_migrations.schema_migrations) <> 19 then
    raise exception 'Ledger changed inside the schema transaction: STOP (transaction rolls back)'; end if;
  raise notice 'V3.2 ATOMIC APPLY SUCCEEDED (statement_timeout=%, lock_timeout=%), committing',
    current_setting('statement_timeout'), current_setting('lock_timeout');
end
$done$;
