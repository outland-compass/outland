-- Additive transactional ownership gate for universe-scoped root entities.
-- Staging-first; NOT executed by this commit.
begin;
create or replace function public.sideworld_studio_guarded_save_root(
  p_universe_slug text, p_entity text, p_input jsonb
) returns uuid
language plpgsql security definer
set search_path = pg_catalog, public
as $fn$
declare
  v_universe uuid;
  v_existing uuid;
  v_id uuid;
  v_requested uuid;
begin
  if p_entity not in ('world','theme','franchise') then
    raise exception 'Unsupported guarded entity' using errcode = '22023';
  end if;
  if p_input is null or jsonb_typeof(p_input) <> 'object' then
    raise exception 'Invalid payload' using errcode = '22023';
  end if;
  select id into v_universe from universe.universes
    where slug = p_universe_slug for update;
  if v_universe is null then
    raise exception 'Unknown universe' using errcode = '22023';
  end if;
  v_requested := nullif(p_input->>'p_universe_id','')::uuid;
  if v_requested is distinct from v_universe then
    raise exception 'Universe mismatch' using errcode = '42501';
  end if;
  v_id := nullif(p_input->>'p_id','')::uuid;
  if v_id is not null then
    if p_entity = 'world' then
      select universe_id into v_existing from universe.worlds where id=v_id for update;
    elsif p_entity = 'theme' then
      select universe_id into v_existing from universe.themes where id=v_id for update;
    else
      select universe_id into v_existing from canon.franchises where id=v_id for update;
    end if;
    if v_existing is distinct from v_universe then
      raise exception 'Existing entity does not belong to selected universe' using errcode = '42501';
    end if;
  end if;
  if p_entity = 'world' then
    return public.sideworld_studio_save_world(
      v_id,v_universe,p_input->>'p_slug',p_input->>'p_name',
      p_input->>'p_status',p_input->>'p_summary');
  elsif p_entity = 'theme' then
    return public.sideworld_studio_save_theme(
      v_id,v_universe,p_input->>'p_slug',p_input->>'p_name',
      p_input->>'p_description',p_input->>'p_status');
  else
    return public.sideworld_studio_save_franchise(
      v_id,v_universe,p_input->>'p_slug',p_input->>'p_name',
      p_input->>'p_description',p_input->>'p_status',
      (p_input->>'p_canon_version')::integer);
  end if;
end;
$fn$;
revoke all on function public.sideworld_studio_guarded_save_root(text,text,jsonb) from public, anon, authenticated;
grant execute on function public.sideworld_studio_guarded_save_root(text,text,jsonb) to service_role;
commit;
-- Rollback after app rollback: drop function public.sideworld_studio_guarded_save_root(text,text,jsonb);
