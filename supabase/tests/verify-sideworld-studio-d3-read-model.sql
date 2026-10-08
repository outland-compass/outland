-- verify-sideworld-studio-d3-read-model.sql
begin;

do $verify$
declare
  payload jsonb;
begin
  if to_regprocedure('public.sideworld_studio_read_model(text)') is null then
    raise exception 'Studio read model RPC missing';
  end if;

  if has_function_privilege('anon','public.sideworld_studio_read_model(text)','EXECUTE')
     or has_function_privilege('authenticated','public.sideworld_studio_read_model(text)','EXECUTE') then
    raise exception 'Browser role can execute Studio read model';
  end if;

  set local role service_role;
  select public.sideworld_studio_read_model('__missing_universe__') into payload;
  reset role;

  if not (payload ? 'worlds')
     or not (payload ? 'themes')
     or not (payload ? 'worldCities')
     or not (payload ? 'cities')
     or not (payload ? 'franchises') then
    raise exception 'Studio read model is missing required V0-D3 keys: %', payload;
  end if;
end
$verify$;

rollback;
