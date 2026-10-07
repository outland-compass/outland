-- SIDEWORLD Studio V0-D1 — narrow server-only authoring RPCs.
-- Additive only. Private authoring schemas remain outside Data API exposure.
-- No direct table/schema grants are added for API roles.

create or replace function public.sideworld_studio_save_universe(
  p_id uuid,
  p_slug text,
  p_name text,
  p_visibility text,
  p_status text,
  p_description text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into universe.universes(slug,name,visibility,status,description)
    values (btrim(p_slug),btrim(p_name),p_visibility,p_status,nullif(btrim(coalesce(p_description,'')),''))
    returning id into v_id;
  else
    update universe.universes
       set slug=btrim(p_slug), name=btrim(p_name), visibility=p_visibility, status=p_status,
           description=nullif(btrim(coalesce(p_description,'')),'')
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Universe not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_franchise(
  p_id uuid,
  p_universe_id uuid,
  p_slug text,
  p_name text,
  p_description text,
  p_status text,
  p_canon_version integer
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into canon.franchises(universe_id,slug,name,description,status,canon_version)
    values (p_universe_id,btrim(p_slug),btrim(p_name),nullif(btrim(coalesce(p_description,'')),''),p_status,p_canon_version)
    returning id into v_id;
  else
    update canon.franchises
       set universe_id=p_universe_id, slug=btrim(p_slug), name=btrim(p_name),
           description=nullif(btrim(coalesce(p_description,'')),''), status=p_status, canon_version=p_canon_version
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Franchise not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_series(
  p_id uuid,
  p_franchise_id uuid,
  p_theme_id uuid,
  p_slug text,
  p_name text,
  p_premise text,
  p_status text,
  p_sort_order integer
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into canon.series(franchise_id,theme_id,slug,name,premise,status,sort_order)
    values (p_franchise_id,p_theme_id,btrim(p_slug),btrim(p_name),nullif(btrim(coalesce(p_premise,'')),''),p_status,p_sort_order)
    returning id into v_id;
  else
    update canon.series
       set franchise_id=p_franchise_id, theme_id=p_theme_id, slug=btrim(p_slug), name=btrim(p_name),
           premise=nullif(btrim(coalesce(p_premise,'')),''), status=p_status, sort_order=p_sort_order
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Series not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_lore_fact(
  p_id uuid,
  p_franchise_id uuid,
  p_series_id uuid,
  p_fact_key text,
  p_statement text,
  p_canon_status text,
  p_reveal_phase text,
  p_visibility text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into canon.lore_facts(franchise_id,series_id,fact_key,statement,canon_status,reveal_phase,visibility)
    values (p_franchise_id,p_series_id,btrim(p_fact_key),btrim(p_statement),p_canon_status,
            nullif(btrim(coalesce(p_reveal_phase,'')),''),p_visibility)
    returning id into v_id;
  else
    update canon.lore_facts
       set franchise_id=p_franchise_id, series_id=p_series_id, fact_key=btrim(p_fact_key),
           statement=btrim(p_statement), canon_status=p_canon_status,
           reveal_phase=nullif(btrim(coalesce(p_reveal_phase,'')),''), visibility=p_visibility
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Lore fact not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_canon_rule(
  p_id uuid,
  p_franchise_id uuid,
  p_series_id uuid,
  p_character_id uuid,
  p_rule_type text,
  p_rule_text text,
  p_severity text,
  p_status text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into canon.canon_rules(franchise_id,series_id,character_id,rule_type,rule_text,severity,status)
    values (p_franchise_id,p_series_id,p_character_id,btrim(p_rule_type),btrim(p_rule_text),p_severity,p_status)
    returning id into v_id;
  else
    update canon.canon_rules
       set franchise_id=p_franchise_id, series_id=p_series_id, character_id=p_character_id,
           rule_type=btrim(p_rule_type), rule_text=btrim(p_rule_text), severity=p_severity, status=p_status
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Canon rule not found'; end if;
  end if;
  return v_id;
end $$;

do $privileges$
declare fn regprocedure;
begin
  foreach fn in array array[
    'public.sideworld_studio_save_universe(uuid,text,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_franchise(uuid,uuid,text,text,text,text,integer)'::regprocedure,
    'public.sideworld_studio_save_series(uuid,uuid,uuid,text,text,text,integer)'::regprocedure,
    'public.sideworld_studio_save_lore_fact(uuid,uuid,uuid,text,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_canon_rule(uuid,uuid,uuid,uuid,text,text,text,text)'::regprocedure
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', fn);
    execute format('grant execute on function %s to service_role', fn);
  end loop;
end
$privileges$;
