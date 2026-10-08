-- verify-sideworld-studio-d3-context-ready.sql
begin;

do $verify$
declare
  fn regprocedure;
  funcs regprocedure[] := array[
    'public.sideworld_studio_save_character_relationship(uuid,uuid,uuid,uuid,text,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_character_profiles(uuid,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb)'::regprocedure,
    'public.sideworld_studio_save_theme_style(uuid,jsonb)'::regprocedure,
    'public.sideworld_studio_read_model(text)'::regprocedure
  ];
begin
  foreach fn in array funcs loop
    if not (select prosecdef from pg_proc where oid=fn) then
      raise exception 'Studio D3 RPC % is not SECURITY DEFINER',fn;
    end if;
    if has_function_privilege('anon',fn,'EXECUTE')
       or has_function_privilege('authenticated',fn,'EXECUTE') then
      raise exception 'Browser role can execute Studio D3 RPC %',fn;
    end if;
    if not has_function_privilege('service_role',fn,'EXECUTE') then
      raise exception 'service_role cannot execute Studio D3 RPC %',fn;
    end if;
  end loop;
end
$verify$;

set local role service_role;

do $smoke$
declare
  u uuid;
  t uuid;
  f uuid;
  a uuid;
  b uuid;
  rel uuid;
  payload jsonb;
begin
  u := public.sideworld_studio_save_universe(null,'ci-d3-universe','CI D3 Universe','private','draft','temporary');
  t := public.sideworld_studio_save_theme(null,u,'ci-d3-theme','CI D3 Theme','temporary','draft');
  f := public.sideworld_studio_save_franchise(null,u,'ci-d3-franchise','CI D3 Franchise','temporary','draft',1);
  a := public.sideworld_studio_save_character(null,f,'ci-a','CI A','CI A','guide',30,'temporary','draft');
  b := public.sideworld_studio_save_character(null,f,'ci-b','CI B','CI B','rival',31,'temporary','draft');

  perform public.sideworld_studio_save_theme_style(t,'{"tone":"mysterious","palette":["navy","signal-blue"]}'::jsonb);
  perform public.sideworld_studio_save_character_profiles(
    a,
    '{"identity":"cartographer"}'::jsonb,
    '{"traits":["curious"]}'::jsonb,
    '{"knows":["phase-1"]}'::jsonb,
    '{"register":"precise"}'::jsonb,
    '{"silhouette":"distinct"}'::jsonb,
    '{"must_not":["invent_global_canon"]}'::jsonb
  );
  rel := public.sideworld_studio_save_character_relationship(
    null,f,a,b,'rivalry','Temporary relationship','draft','phase-1',null
  );

  payload := public.sideworld_studio_read_model('ci-d3-universe');

  if jsonb_array_length(payload->'themes') <> 1 then raise exception 'D3 read model theme missing'; end if;
  if jsonb_array_length(payload->'characters') <> 2 then raise exception 'D3 read model characters missing'; end if;
  if jsonb_array_length(payload->'relationships') <> 1 then raise exception 'D3 read model relationship missing'; end if;
  if (payload->'themes'->0->'styleProfile'->>'tone') <> 'mysterious' then raise exception 'Theme profile missing'; end if;
  if (payload->'characters'->0 ? 'identityProfile') is false then raise exception 'Character profile missing'; end if;

  perform public.sideworld_studio_save_character_relationship(
    rel,f,a,b,'rivalry','Updated relationship','proposed','phase-1','phase-3'
  );
end
$smoke$;

reset role;

do $assert$
begin
  if not exists (
    select 1 from canon.character_relationships
    where relationship_type='rivalry' and description='Updated relationship'
      and canon_status='proposed' and valid_to_phase='phase-3'
  ) then
    raise exception 'D3 relationship update smoke failed';
  end if;
end
$assert$;

rollback;
