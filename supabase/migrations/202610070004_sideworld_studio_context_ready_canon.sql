-- SIDEWORLD Studio V0-D3 — context-ready canon.
-- Completes the read model with Worlds, Themes and Character Relationships,
-- and adds narrow authoring RPCs for relationships and structured profiles.

create or replace function public.sideworld_studio_save_character_relationship(
  p_id uuid,
  p_franchise_id uuid,
  p_character_a_id uuid,
  p_character_b_id uuid,
  p_relationship_type text,
  p_description text,
  p_canon_status text,
  p_valid_from_phase text,
  p_valid_to_phase text
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  if p_id is null then
    insert into canon.character_relationships(
      franchise_id,character_a_id,character_b_id,relationship_type,description,
      canon_status,valid_from_phase,valid_to_phase
    )
    values (
      p_franchise_id,p_character_a_id,p_character_b_id,btrim(p_relationship_type),
      nullif(btrim(coalesce(p_description,'')),''),
      p_canon_status,
      nullif(btrim(coalesce(p_valid_from_phase,'')),''),
      nullif(btrim(coalesce(p_valid_to_phase,'')),'')
    )
    returning id into v_id;
  else
    update canon.character_relationships
       set franchise_id=p_franchise_id,
           character_a_id=p_character_a_id,
           character_b_id=p_character_b_id,
           relationship_type=btrim(p_relationship_type),
           description=nullif(btrim(coalesce(p_description,'')),''),
           canon_status=p_canon_status,
           valid_from_phase=nullif(btrim(coalesce(p_valid_from_phase,'')),''),
           valid_to_phase=nullif(btrim(coalesce(p_valid_to_phase,'')),'')
     where id=p_id
     returning id into v_id;
    if v_id is null then raise exception 'Character relationship not found'; end if;
  end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_character_profiles(
  p_character_id uuid,
  p_identity_profile jsonb,
  p_personality_profile jsonb,
  p_knowledge_profile jsonb,
  p_voice_profile jsonb,
  p_visual_profile jsonb,
  p_ai_rules jsonb
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  update canon.characters
     set identity_profile=coalesce(p_identity_profile,'{}'::jsonb),
         personality_profile=coalesce(p_personality_profile,'{}'::jsonb),
         knowledge_profile=coalesce(p_knowledge_profile,'{}'::jsonb),
         voice_profile=coalesce(p_voice_profile,'{}'::jsonb),
         visual_profile=coalesce(p_visual_profile,'{}'::jsonb),
         ai_rules=coalesce(p_ai_rules,'{}'::jsonb)
   where id=p_character_id
   returning id into v_id;
  if v_id is null then raise exception 'Character not found'; end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_save_theme_style(
  p_theme_id uuid,
  p_style_profile jsonb
) returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare v_id uuid;
begin
  update universe.themes
     set style_profile=coalesce(p_style_profile,'{}'::jsonb)
   where id=p_theme_id
   returning id into v_id;
  if v_id is null then raise exception 'Theme not found'; end if;
  return v_id;
end $$;

create or replace function public.sideworld_studio_read_model(p_universe_slug text)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
with selected_universe as (
  select u.id,u.slug,u.name,u.visibility,u.status,u.description
  from universe.universes u
  where u.slug=p_universe_slug
  limit 1
),
selected_worlds as (
  select w.*
  from universe.worlds w
  join selected_universe u on u.id=w.universe_id
),
selected_themes as (
  select t.*
  from universe.themes t
  left join selected_universe u on u.id=t.universe_id
  where t.universe_id is null or u.id is not null
),
selected_franchises as (
  select f.*
  from canon.franchises f
  join selected_universe u on u.id=f.universe_id
),
selected_series as (
  select s.*
  from canon.series s
  join selected_franchises f on f.id=s.franchise_id
),
selected_characters as (
  select c.*
  from canon.characters c
  join selected_franchises f on f.id=c.franchise_id
)
select jsonb_build_object(
  'universe',
    (select jsonb_build_object(
      'id',u.id,'slug',u.slug,'name',u.name,'visibility',u.visibility,
      'status',u.status,'description',u.description
    ) from selected_universe u),
  'worlds',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',w.id,'universeId',w.universe_id,'slug',w.slug,'name',w.name,
      'status',w.status,'summary',w.summary
    ) order by w.name,w.id) from selected_worlds w),'[]'::jsonb),
  'themes',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',t.id,'universeId',t.universe_id,'slug',t.slug,'name',t.name,
      'description',t.description,'status',t.status,'styleProfile',t.style_profile
    ) order by t.name,t.id) from selected_themes t),'[]'::jsonb),
  'franchises',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',f.id,'universeId',f.universe_id,'slug',f.slug,'name',f.name,
      'description',f.description,'status',f.status,'canonVersion',f.canon_version
    ) order by f.name,f.id) from selected_franchises f),'[]'::jsonb),
  'series',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',s.id,'franchiseId',s.franchise_id,'themeId',s.theme_id,'slug',s.slug,
      'name',s.name,'premise',s.premise,'status',s.status,'sortOrder',s.sort_order
    ) order by s.sort_order,s.name,s.id) from selected_series s),'[]'::jsonb),
  'characters',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',c.id,'franchiseId',c.franchise_id,'slug',c.slug,'name',c.name,
      'displayName',c.display_name,'role',c.role,'age',c.age,'bio',c.bio,
      'canonStatus',c.canon_status,
      'identityProfile',c.identity_profile,
      'personalityProfile',c.personality_profile,
      'knowledgeProfile',c.knowledge_profile,
      'voiceProfile',c.voice_profile,
      'visualProfile',c.visual_profile,
      'aiRules',c.ai_rules
    ) order by c.name,c.id) from selected_characters c),'[]'::jsonb),
  'relationships',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',r.id,'franchiseId',r.franchise_id,
      'characterAId',r.character_a_id,'characterBId',r.character_b_id,
      'relationshipType',r.relationship_type,'description',r.description,
      'canonStatus',r.canon_status,'validFromPhase',r.valid_from_phase,
      'validToPhase',r.valid_to_phase
    ) order by r.relationship_type,r.id)
    from canon.character_relationships r
    join selected_franchises f on f.id=r.franchise_id),'[]'::jsonb),
  'factions',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',x.id,'franchiseId',x.franchise_id,'slug',x.slug,'name',x.name,
      'factionType',x.faction_type,'description',x.description,
      'visibility',x.visibility,'canonStatus',x.canon_status
    ) order by x.name,x.id)
    from canon.factions x join selected_franchises f on f.id=x.franchise_id),'[]'::jsonb),
  'lore',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',l.id,'franchiseId',l.franchise_id,'seriesId',l.series_id,
      'factKey',l.fact_key,'statement',l.statement,'canonStatus',l.canon_status,
      'revealPhase',l.reveal_phase,'visibility',l.visibility
    ) order by l.fact_key,l.id)
    from canon.lore_facts l join selected_franchises f on f.id=l.franchise_id),'[]'::jsonb),
  'rules',
    coalesce((select jsonb_agg(jsonb_build_object(
      'id',r.id,'franchiseId',r.franchise_id,'seriesId',r.series_id,
      'characterId',r.character_id,'ruleType',r.rule_type,'ruleText',r.rule_text,
      'severity',r.severity,'status',r.status
    ) order by case r.severity when 'error' then 1 when 'warning' then 2 else 3 end,r.rule_type,r.id)
    from canon.canon_rules r join selected_franchises f on f.id=r.franchise_id),'[]'::jsonb),
  'cities',
    coalesce((select jsonb_agg(to_jsonb(city_row) order by city_row.name,city_row.id)
      from (
        select distinct c.id,c.country_code as "countryCode",c.slug,c.name,c.region,
          c.timezone,c.default_locale as "defaultLocale",c.status,
          c.verification_status as "verificationStatus"
        from selected_worlds w
        join universe.world_cities wc on wc.world_id=w.id
        join geo.cities c on c.id=wc.city_id
      ) city_row),'[]'::jsonb)
);
$$;

do $privileges$
declare fn regprocedure;
begin
  foreach fn in array array[
    'public.sideworld_studio_save_character_relationship(uuid,uuid,uuid,uuid,text,text,text,text,text)'::regprocedure,
    'public.sideworld_studio_save_character_profiles(uuid,jsonb,jsonb,jsonb,jsonb,jsonb,jsonb)'::regprocedure,
    'public.sideworld_studio_save_theme_style(uuid,jsonb)'::regprocedure,
    'public.sideworld_studio_read_model(text)'::regprocedure
  ] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role',fn);
    execute format('grant execute on function %s to service_role',fn);
  end loop;
end
$privileges$;
