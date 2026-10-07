-- verify-sideworld-studio-read-api.sql
begin;

do $verify$
begin
  if to_regprocedure('public.sideworld_studio_snapshot(uuid)') is null then
    raise exception 'Missing SIDEWORLD Studio snapshot RPC';
  end if;

  if not exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'sideworld_studio_snapshot'
      and p.prosecdef
  ) then
    raise exception 'Studio snapshot RPC must be SECURITY DEFINER';
  end if;

  if has_function_privilege('anon', 'public.sideworld_studio_snapshot(uuid)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.sideworld_studio_snapshot(uuid)', 'EXECUTE') then
    raise exception 'Studio snapshot RPC exposed to browser API roles';
  end if;

  if not has_function_privilege('service_role', 'public.sideworld_studio_snapshot(uuid)', 'EXECUTE') then
    raise exception 'service_role cannot execute Studio snapshot RPC';
  end if;

  if has_schema_privilege('service_role','universe','USAGE')
     or has_schema_privilege('service_role','geo','USAGE')
     or has_schema_privilege('service_role','canon','USAGE') then
    raise exception 'Studio read facade must not expose private authoring schemas to service_role';
  end if;
end
$verify$;

set local role service_role;
select public.sideworld_studio_snapshot(null::uuid);
reset role;

rollback;
