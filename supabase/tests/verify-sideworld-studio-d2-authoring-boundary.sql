-- verify-sideworld-studio-d2-authoring-boundary.sql
begin;

do $verify$
declare
  fn regprocedure;
  funcs regprocedure[] := array[
    'public.sideworld_studio_save_world(uuid,uuid,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_theme(uuid,uuid,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_character(uuid,uuid,text,text,text,text,integer,text,text)'::regprocedure,
    'public.sideworld_studio_save_faction(uuid,uuid,text,text,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_country(text,text,text)'::regprocedure,
    'public.sideworld_studio_save_city(uuid,text,text,text,text,text,text,numeric,numeric,text,text)'::regprocedure,
    'public.sideworld_studio_save_world_city(uuid,uuid,text)'::regprocedure
  ];
begin
  foreach fn in array funcs loop
    if not (select prosecdef from pg_proc where oid=fn) then
      raise exception 'Studio D2 RPC % is not SECURITY DEFINER', fn;
    end if;
    if has_function_privilege('anon',fn,'EXECUTE')
       or has_function_privilege('authenticated',fn,'EXECUTE') then
      raise exception 'Browser role can execute Studio D2 RPC %', fn;
    end if;
    if not has_function_privilege('service_role',fn,'EXECUTE') then
      raise exception 'service_role cannot execute Studio D2 RPC %', fn;
    end if;
  end loop;
end
$verify$;

set local role service_role;

do $smoke$
declare
  u uuid;
  w uuid;
  t uuid;
  f uuid;
  c uuid;
  x uuid;
  city uuid;
  rel text;
begin
  u := public.sideworld_studio_save_universe(null,'ci-d2-universe','CI D2 Universe','private','draft','temporary');
  w := public.sideworld_studio_save_world(null,u,'ci-world','CI World','draft','temporary');
  t := public.sideworld_studio_save_theme(null,u,'ci-theme','CI Theme','temporary','draft');
  f := public.sideworld_studio_save_franchise(null,u,'ci-d2-franchise','CI D2 Franchise','temporary','draft',1);
  c := public.sideworld_studio_save_character(null,f,'ci-character','CI Character','CI Character','guide',42,'temporary','draft');
  x := public.sideworld_studio_save_faction(null,f,'ci-faction','CI Faction','guild','temporary','hidden','draft');
  perform public.sideworld_studio_save_country('RS','Serbia','sr-RS');
  city := public.sideworld_studio_save_city(null,'RS','ci-city','CI City','Vojvodina','Europe/Belgrade','sr-RS',45.0,19.0,'draft','unverified');
  rel := public.sideworld_studio_save_world_city(w,city,'story');

  perform public.sideworld_studio_save_world(w,u,'ci-world','CI World Updated','draft','temporary');
  perform public.sideworld_studio_save_theme(t,u,'ci-theme','CI Theme Updated','temporary','draft');
  perform public.sideworld_studio_save_character(c,f,'ci-character','CI Character Updated','CI Character','guide',42,'temporary','draft');
  perform public.sideworld_studio_save_faction(x,f,'ci-faction','CI Faction Updated','guild','temporary','hidden','draft');
  perform public.sideworld_studio_save_city(city,'RS','ci-city','CI City Updated','Vojvodina','Europe/Belgrade','sr-RS',45.0,19.0,'draft','unverified');
  perform public.sideworld_studio_save_world_city(w,city,'primary');

  if rel is null then raise exception 'World-city authoring returned no key'; end if;
end
$smoke$;

reset role;

do $assert$
begin
  if not exists (select 1 from universe.worlds where slug='ci-world' and name='CI World Updated') then
    raise exception 'World authoring smoke failed';
  end if;
  if not exists (select 1 from universe.themes where slug='ci-theme' and name='CI Theme Updated') then
    raise exception 'Theme authoring smoke failed';
  end if;
  if not exists (select 1 from canon.characters where slug='ci-character' and name='CI Character Updated') then
    raise exception 'Character authoring smoke failed';
  end if;
  if not exists (select 1 from canon.factions where slug='ci-faction' and name='CI Faction Updated') then
    raise exception 'Faction authoring smoke failed';
  end if;
  if not exists (select 1 from geo.countries where code='RS' and name='Serbia') then
    raise exception 'Country authoring smoke failed';
  end if;
  if not exists (select 1 from geo.cities where slug='ci-city' and name='CI City Updated') then
    raise exception 'City authoring smoke failed';
  end if;
  if not exists (
    select 1
    from universe.world_cities wc
    join universe.worlds w on w.id=wc.world_id
    join geo.cities c on c.id=wc.city_id
    where w.slug='ci-world' and c.slug='ci-city' and wc.relationship_type='primary'
  ) then
    raise exception 'World-city mapping smoke failed';
  end if;
end
$assert$;

rollback;
