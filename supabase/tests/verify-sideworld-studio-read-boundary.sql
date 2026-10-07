-- verify-sideworld-studio-read-boundary.sql
-- Verifies the V0-C RPC is the only new server read boundary and does not expose private schemas.
begin;

do $verify$
declare
  fn_oid oid;
begin
  select p.oid
  into fn_oid
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'sideworld_studio_read_model'
    and pg_get_function_identity_arguments(p.oid) = 'p_universe_slug text';

  if fn_oid is null then
    raise exception 'Studio read-model RPC missing';
  end if;

  if not (select prosecdef from pg_proc where oid = fn_oid) then
    raise exception 'Studio read-model RPC must be SECURITY DEFINER';
  end if;

  if has_function_privilege('public', fn_oid, 'EXECUTE')
     or has_function_privilege('anon', fn_oid, 'EXECUTE')
     or has_function_privilege('authenticated', fn_oid, 'EXECUTE') then
    raise exception 'Studio read-model RPC is executable by a browser/public role';
  end if;

  if not has_function_privilege('service_role', fn_oid, 'EXECUTE') then
    raise exception 'service_role cannot execute Studio read-model RPC';
  end if;

  if has_schema_privilege('anon', 'universe', 'USAGE')
     or has_schema_privilege('authenticated', 'universe', 'USAGE')
     or has_schema_privilege('service_role', 'universe', 'USAGE')
     or has_schema_privilege('anon', 'geo', 'USAGE')
     or has_schema_privilege('authenticated', 'geo', 'USAGE')
     or has_schema_privilege('service_role', 'geo', 'USAGE')
     or has_schema_privilege('anon', 'canon', 'USAGE')
     or has_schema_privilege('authenticated', 'canon', 'USAGE')
     or has_schema_privilege('service_role', 'canon', 'USAGE') then
    raise exception 'Private SIDEWORLD schemas gained direct API-role USAGE';
  end if;
end
$verify$;

-- Prove the service role can invoke the RPC without direct private-schema grants.
set local role service_role;
select public.sideworld_studio_read_model('__missing_universe__');
reset role;

rollback;
