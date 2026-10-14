-- Transactional, fail-closed canon writes. Additive, not yet applied.
begin;
create or replace function public.sideworld_studio_guarded_save_canon(
 p_universe_slug text, p_entity text, p_input jsonb
) returns uuid language plpgsql security definer
set search_path = pg_catalog, public
as $fn$
declare
 v_universe uuid;
 v_franchise uuid;
 v_id uuid;
 v_parent uuid;
 v_ref uuid;
 v_theme_universe uuid;
 v_series_franchise uuid;
 v_character_franchise uuid;
begin
 if p_entity not in ('series','character','faction','lore','rule') or
    p_input is null or jsonb_typeof(p_input) <> 'object' then
   raise exception 'Invalid guarded canon request' using errcode='22023';
 end if;
 select id into v_universe from universe.universes where slug=p_universe_slug for update;
 if v_universe is null then raise exception 'Unknown universe' using errcode='42501'; end if;
 v_franchise := nullif(p_input->>'p_franchise_id','')::uuid;
 select universe_id into v_parent from canon.franchises where id=v_franchise for update;
 if v_parent is distinct from v_universe then
   raise exception 'Franchise universe mismatch' using errcode='42501';
 end if;
 v_id := nullif(p_input->>'p_id','')::uuid;
 if v_id is not null then
   v_parent := null;
   if p_entity='series' then
     select franchise_id into v_parent from canon.series where id=v_id for update;
   elsif p_entity='character' then
     select franchise_id into v_parent from canon.characters where id=v_id for update;
   elsif p_entity='faction' then
     select franchise_id into v_parent from canon.factions where id=v_id for update;
   elsif p_entity='lore' then
     select franchise_id into v_parent from canon.lore_facts where id=v_id for update;
   else
     select franchise_id into v_parent from canon.canon_rules where id=v_id for update;
   end if;
   if v_parent is distinct from v_franchise then
     raise exception 'Existing canon entity cannot be reparented' using errcode='42501';
   end if;
 end if;
 if p_entity='series' then
   v_ref := nullif(p_input->>'p_theme_id','')::uuid;
   if v_ref is not null then
     select universe_id into v_theme_universe from universe.themes where id=v_ref for update;
     if v_theme_universe is distinct from v_universe then
       raise exception 'Theme universe mismatch' using errcode='42501';
     end if;
   end if;
   return public.sideworld_studio_save_series(
     v_id,v_franchise,v_ref,p_input->>'p_slug',p_input->>'p_name',
     p_input->>'p_premise',p_input->>'p_status',(p_input->>'p_sort_order')::integer);
 elsif p_entity='character' then
   return public.sideworld_studio_save_character(
     v_id,v_franchise,p_input->>'p_slug',p_input->>'p_name',
     p_input->>'p_display_name',p_input->>'p_role',
     (p_input->>'p_age')::integer,p_input->>'p_bio',p_input->>'p_canon_status');
 elsif p_entity='faction' then
   return public.sideworld_studio_save_faction(
     v_id,v_franchise,p_input->>'p_slug',p_input->>'p_name',
     p_input->>'p_faction_type',p_input->>'p_description',
     p_input->>'p_visibility',p_input->>'p_canon_status');
 elsif p_entity='lore' then
   v_ref := nullif(p_input->>'p_series_id','')::uuid;
   if v_ref is not null then
     select franchise_id into v_series_franchise from canon.series where id=v_ref for update;
     if v_series_franchise is distinct from v_franchise then
       raise exception 'Lore series franchise mismatch' using errcode='42501';
     end if;
   end if;
   return public.sideworld_studio_save_lore_fact(
     v_id,v_franchise,v_ref,p_input->>'p_fact_key',p_input->>'p_statement',
     p_input->>'p_canon_status',p_input->>'p_reveal_phase',p_input->>'p_visibility');
 else
   v_ref := nullif(p_input->>'p_series_id','')::uuid;
   if v_ref is not null then
     select franchise_id into v_series_franchise from canon.series where id=v_ref for update;
     if v_series_franchise is distinct from v_franchise then
       raise exception 'Rule series franchise mismatch' using errcode='42501';
     end if;
   end if;
   v_parent := nullif(p_input->>'p_character_id','')::uuid;
   if v_parent is not null then
     select franchise_id into v_character_franchise from canon.characters where id=v_parent for update;
     if v_character_franchise is distinct from v_franchise then
       raise exception 'Rule character franchise mismatch' using errcode='42501';
     end if;
   end if;
   return public.sideworld_studio_save_canon_rule(
     v_id,v_franchise,v_ref,v_parent,p_input->>'p_rule_type',p_input->>'p_rule_text',
     p_input->>'p_severity',p_input->>'p_status');
 end if;
end;
$fn$;
revoke all on function public.sideworld_studio_guarded_save_canon(text,text,jsonb) from public, anon, authenticated;
grant execute on function public.sideworld_studio_guarded_save_canon(text,text,jsonb) to service_role;
commit;
-- Rollback after callers are removed: drop function public.sideworld_studio_guarded_save_canon(text,text,jsonb);
