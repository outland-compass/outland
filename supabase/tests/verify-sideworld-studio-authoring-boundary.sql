-- verify-sideworld-studio-authoring-boundary.sql
begin;

do $verify$
declare
  fn regprocedure;
  funcs regprocedure[] := array[
    'public.sideworld_studio_save_universe(uuid,text,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_franchise(uuid,uuid,text,text,text,text,integer)'::regprocedure,
    'public.sideworld_studio_save_series(uuid,uuid,uuid,text,text,text,text,integer)'::regprocedure,
    'public.sideworld_studio_save_lore_fact(uuid,uuid,uuid,text,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_canon_rule(uuid,uuid,uuid,uuid,text,text,text,text)'::regprocedure
  ];
begin
  foreach fn in array funcs loop
    if not (select prosecdef from pg_proc where oid=fn) then
      raise exception 'Studio authoring RPC % is not SECURITY DEFINER', fn;
    end if;
    if has_function_privilege('anon',fn,'EXECUTE')
       or has_function_privilege('authenticated',fn,'EXECUTE') then
      raise exception 'Browser role can execute Studio authoring RPC %', fn;
    end if;
    if not has_function_privilege('service_role',fn,'EXECUTE') then
      raise exception 'service_role cannot execute Studio authoring RPC %', fn;
    end if;
  end loop;

  if has_schema_privilege('anon','universe','USAGE')
     or has_schema_privilege('authenticated','universe','USAGE')
     or has_schema_privilege('service_role','universe','USAGE')
     or has_schema_privilege('anon','canon','USAGE')
     or has_schema_privilege('authenticated','canon','USAGE')
     or has_schema_privilege('service_role','canon','USAGE') then
    raise exception 'Private SIDEWORLD schema received direct API-role USAGE';
  end if;
end
$verify$;

-- Exercise create/update semantics inside the transaction and roll it all back.
set local role service_role;

do $smoke$
declare
  u uuid;
  f uuid;
  s uuid;
  l uuid;
  r uuid;
begin
  u := public.sideworld_studio_save_universe(null,'ci-studio-universe','CI Studio Universe','private','draft','temporary');
  f := public.sideworld_studio_save_franchise(null,u,'ci-franchise','CI Franchise','temporary','draft',1);
  s := public.sideworld_studio_save_series(null,f,null,'ci-series','CI Series','temporary','draft',100);
  l := public.sideworld_studio_save_lore_fact(null,f,s,'ci.fact','Temporary lore fact','draft',null,'internal');
  r := public.sideworld_studio_save_canon_rule(null,f,s,null,'continuity','Temporary rule','error','draft');

  perform public.sideworld_studio_save_universe(u,'ci-studio-universe','CI Studio Universe Updated','private','draft','temporary');
  perform public.sideworld_studio_save_franchise(f,u,'ci-franchise','CI Franchise Updated','temporary','draft',1);
  perform public.sideworld_studio_save_series(s,f,null,'ci-series','CI Series Updated','temporary','draft',100);
  perform public.sideworld_studio_save_lore_fact(l,f,s,'ci.fact','Temporary lore fact updated','draft',null,'internal');
  perform public.sideworld_studio_save_canon_rule(r,f,s,null,'continuity','Temporary rule updated','error','draft');

  if not exists (select 1 from universe.universes where id=u and name='CI Studio Universe Updated') then
    raise exception 'Universe authoring smoke failed';
  end if;
  if not exists (select 1 from canon.franchises where id=f and name='CI Franchise Updated') then
    raise exception 'Franchise authoring smoke failed';
  end if;
  if not exists (select 1 from canon.series where id=s and name='CI Series Updated') then
    raise exception 'Series authoring smoke failed';
  end if;
  if not exists (select 1 from canon.lore_facts where id=l and statement='Temporary lore fact updated') then
    raise exception 'Lore authoring smoke failed';
  end if;
  if not exists (select 1 from canon.canon_rules where id=r and rule_text='Temporary rule updated') then
    raise exception 'Rule authoring smoke failed';
  end if;
end
$smoke$;

reset role;
rollback;
