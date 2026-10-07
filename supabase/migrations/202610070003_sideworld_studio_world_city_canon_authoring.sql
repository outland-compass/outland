-- SIDEWORLD Studio V0-D2 — Worlds, themes, characters, factions and cities authoring.
-- Additive only. Private schemas remain outside Data API exposure.

create or replace function public.sideworld_studio_save_world(
  p_id uuid,
  p_universe_id uuid,
  p_slug text,
  p_name text,
  p_status text,
  p_summary text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into universe.worlds(universe_id,slug,name,status,summary)
    values (p_universe_id,btrim(p_slug),btrim(p_name),p_status,nullif(btrim(coalesce(p_summary,'')),''))
    returning id into v_id;
  else
    update universe.worlds
       set universe_id=p_universe_id, slug=btrim(p_slug), name=btrim(p_name), status=p_status,
           summary=nullif(btrim(coalesce(p_summary,'')),'')
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'World not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_theme(
  p_id uuid,
  p_universe_id uuid,
  p_slug text,
  p_name text,
  p_description text,
  p_status text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into universe.themes(universe_id,slug,name,description,status)
    values (p_universe_id,btrim(p_slug),btrim(p_name),nullif(btrim(coalesce(p_description,'')),''),p_status)
    returning id into v_id;
  else
    update universe.themes
       set universe_id=p_universe_id, slug=btrim(p_slug), name=btrim(p_name),
           description=nullif(btrim(coalesce(p_description,'')),''), status=p_status
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Theme not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_character(
  p_id uuid,
  p_franchise_id uuid,
  p_slug text,
  p_name text,
  p_display_name text,
  p_role text,
  p_age integer,
  p_bio text,
  p_canon_status text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into canon.characters(franchise_id,slug,name,display_name,role,age,bio,canon_status)
    values (
      p_franchise_id,btrim(p_slug),btrim(p_name),
      nullif(btrim(coalesce(p_display_name,'')),''),
      nullif(btrim(coalesce(p_role,'')),''),
      p_age,
      nullif(btrim(coalesce(p_bio,'')),''),
      p_canon_status
    )
    returning id into v_id;
  else
    update canon.characters
       set franchise_id=p_franchise_id, slug=btrim(p_slug), name=btrim(p_name),
           display_name=nullif(btrim(coalesce(p_display_name,'')),''),
           role=nullif(btrim(coalesce(p_role,'')),''),
           age=p_age,
           bio=nullif(btrim(coalesce(p_bio,'')),''),
           canon_status=p_canon_status
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Character not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_faction(
  p_id uuid,
  p_franchise_id uuid,
  p_slug text,
  p_name text,
  p_faction_type text,
  p_description text,
  p_visibility text,
  p_canon_status text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into canon.factions(franchise_id,slug,name,faction_type,description,visibility,canon_status)
    values (
      p_franchise_id,btrim(p_slug),btrim(p_name),
      nullif(btrim(coalesce(p_faction_type,'')),''),
      nullif(btrim(coalesce(p_description,'')),''),
      p_visibility,p_canon_status
    )
    returning id into v_id;
  else
    update canon.factions
       set franchise_id=p_franchise_id, slug=btrim(p_slug), name=btrim(p_name),
           faction_type=nullif(btrim(coalesce(p_faction_type,'')),''),
           description=nullif(btrim(coalesce(p_description,'')),''),
           visibility=p_visibility, canon_status=p_canon_status
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Faction not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_country(
  p_code text,
  p_name text,
  p_default_locale text
) returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_code text;
begin
  v_code := upper(btrim(p_code));
  if char_length(v_code) <> 2 then raise exception 'Country code must be ISO-2'; end if;

  insert into geo.countries(code,name,default_locale)
  values (v_code::char(2),btrim(p_name),nullif(btrim(coalesce(p_default_locale,'')),''))
  on conflict (code) do update
    set name=excluded.name,
        default_locale=excluded.default_locale;

  return v_code;
end $$;

create or replace function public.sideworld_studio_save_city(
  p_id uuid,
  p_country_code text,
  p_slug text,
  p_name text,
  p_region text,
  p_timezone text,
  p_default_locale text,
  p_latitude numeric,
  p_longitude numeric,
  p_status text,
  p_verification_status text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into geo.cities(country_code,slug,name,region,timezone,default_locale,latitude,longitude,status,verification_status)
    values (
      upper(btrim(p_country_code))::char(2),btrim(p_slug),btrim(p_name),
      nullif(btrim(coalesce(p_region,'')),''),
      btrim(p_timezone),btrim(p_default_locale),
      p_latitude,p_longitude,p_status,p_verification_status
    )
    returning id into v_id;
  else
    update geo.cities
       set country_code=upper(btrim(p_country_code))::char(2),
           slug=btrim(p_slug), name=btrim(p_name),
           region=nullif(btrim(coalesce(p_region,'')),''),
           timezone=btrim(p_timezone), default_locale=btrim(p_default_locale),
           latitude=p_latitude, longitude=p_longitude,
           status=p_status, verification_status=p_verification_status
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'City not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_world_city(
  p_world_id uuid,
  p_city_id uuid,
  p_relationship_type text
) returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into universe.world_cities(world_id,city_id,relationship_type)
  values (p_world_id,p_city_id,p_relationship_type)
  on conflict (world_id,city_id) do update
    set relationship_type=excluded.relationship_type;

  return p_world_id::text || ':' || p_city_id::text;
end $$;

do $privileges$
declare fn regprocedure;
begin
  foreach fn in array array[
    'public.sideworld_studio_save_world(uuid,uuid,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_theme(uuid,uuid,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_character(uuid,uuid,text,text,text,text,integer,text,text)'::regprocedure,
    'public.sideworld_studio_save_faction(uuid,uuid,text,text,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_country(text,text,text)'::regprocedure,
    'public.sideworld_studio_save_city(uuid,text,text,text,text,text,text,numeric,numeric,text,text)'::regprocedure,
    'public.sideworld_studio_save_world_city(uuid,uuid,text)'::regprocedure
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', fn);
    execute format('grant execute on function %s to service_role', fn);
  end loop;
end
$privileges$;
