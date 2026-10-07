-- SIDEWORLD Studio V0-C staging post-apply validation. READ ONLY.
\set ON_ERROR_STOP 1
set default_transaction_read_only = on;
begin transaction isolation level repeatable read read only;

do $verify$
declare
  fn oid := to_regprocedure('public.sideworld_studio_read_model(text)');
begin
  if fn is null then raise exception 'Studio read-model RPC missing'; end if;
  if (select count(*) from supabase_migrations.schema_migrations) <> 24
     or (select max(version) from supabase_migrations.schema_migrations) <> '202610070001'
     or not exists (select 1 from supabase_migrations.schema_migrations where version='202610070001') then
    raise exception 'Ledger is not the expected 24-version state';
  end if;
  if not (select prosecdef from pg_proc where oid=fn) then raise exception 'Studio RPC is not SECURITY DEFINER'; end if;
  if has_function_privilege('PUBLIC',fn,'EXECUTE')
     or has_function_privilege('anon',fn,'EXECUTE')
     or has_function_privilege('authenticated',fn,'EXECUTE') then
    raise exception 'Browser/public role can execute Studio RPC';
  end if;
  if not has_function_privilege('service_role',fn,'EXECUTE') then
    raise exception 'service_role cannot execute Studio RPC';
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
    raise exception 'Private SIDEWORLD schemas gained direct API-role USAGE';
  end if;
  raise notice 'STUDIO V0-C STAGING POST-VALIDATION PASSED: 24 versions, service-role-only RPC, private schemas still private';
end
$verify$;

set local role service_role;
select public.sideworld_studio_read_model('__missing_universe__');
reset role;

rollback;
