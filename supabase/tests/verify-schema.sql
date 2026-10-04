begin;

-- Floating-world resolution (rolled back with the rest of this file).
-- Default mode 'canonical' (clean installs): the floating world MUST be code RAFTER, exactly as before.
-- Opt-in mode 'legacy_compatible' (upgraded databases whose world canon predates #27, e.g. staging):
--   PGOPTIONS='-c outland.world_canon=legacy_compatible'
-- uses RAFTER if present, otherwise resolves the single existing world with the floating River/GUARDIAN/FLOW
-- profile (e.g. legacy RIVERKEEPER). No world IDs or records are created or changed.
create function pg_temp.resolve_floating_world() returns uuid
language plpgsql as $resolver$
declare
  v_mode text := coalesce(nullif(current_setting('outland.world_canon', true), ''), 'canonical');
  v_id uuid;
  v_code text;
  v_matches integer;
begin
  if v_mode not in ('canonical', 'legacy_compatible') then
    raise exception 'Unknown outland.world_canon mode: %', v_mode;
  end if;
  select id into v_id from shared.worlds where code = 'RAFTER';
  if v_mode = 'canonical' then
    return v_id; -- NULL when RAFTER is missing: the strict assertions below then fail.
  end if;
  if v_id is not null then
    if exists (select 1 from shared.worlds where code <> 'RAFTER' and asset_kind = 'FLOATING'
               and environment = 'River' and archetype = 'GUARDIAN' and inner_movement = 'FLOW') then
      raise exception 'Ambiguous floating world: RAFTER coexists with another River/GUARDIAN/FLOW floating world';
    end if;
    return v_id;
  end if;
  select count(*), min(id::text)::uuid, min(code) into v_matches, v_id, v_code
  from shared.worlds
  where asset_kind = 'FLOATING' and environment = 'River' and archetype = 'GUARDIAN' and inner_movement = 'FLOW';
  if v_matches <> 1 then
    raise exception 'legacy_compatible: expected exactly one River/GUARDIAN/FLOW floating world, found %', v_matches;
  end if;
  raise notice 'legacy_compatible: floating world resolved by profile to % (%)', v_code, v_id;
  return v_id;
end;
$resolver$;

do $$
declare
  shared_entities text[] := array[
    'profiles', 'user_roles', 'worlds', 'assets', 'activities'
  ];
  land_entities text[] := array[
    'signals', 'candidates', 'candidate_sources', 'candidate_price_history',
    'candidate_media', 'candidate_economics', 'evaluations',
    'evaluation_dimension_weights', 'evaluation_items', 'candidate_gates',
    'dd_items', 'documents', 'evidence_items', 'notes', 'visits', 'decisions',
    'search_profiles', 'candidate_search_profiles', 'mobile_candidate_specs'
  ];
  universe_entities text[] := array['nodes', 'frontiers', 'spots'];
  passport_entities text[] := array['journeys', 'events'];
  entity_name text;
  floating_world_id uuid := pg_temp.resolve_floating_world();
begin
  foreach entity_name in array shared_entities loop
    if to_regclass('shared.' || entity_name) is null then
      raise exception 'Missing shared entity: %', entity_name;
    end if;
  end loop;

  foreach entity_name in array land_entities loop
    if to_regclass('land.' || entity_name) is null then
      raise exception 'Missing land entity: %', entity_name;
    end if;
  end loop;

  foreach entity_name in array array[
    'v_evaluation_dimension_scores', 'v_evaluation_scores',
    'v_candidate_gate_summary', 'v_candidate_latest_evaluation', 'v_candidate_radar'
  ] loop
    if to_regclass('land.' || entity_name) is null then
      raise exception 'Missing read model: %', entity_name;
    end if;
  end loop;

  if not exists (select 1 from shared.worlds where code = 'GREENHILL' and radar_enabled = true) then
    raise exception 'GREENHILL Compass world missing or Radar disabled';
  end if;

  if not exists (select 1 from shared.worlds where id = floating_world_id and radar_enabled = true and asset_kind = 'FLOATING') then
    raise exception 'RAFTER floating Compass world missing or Radar disabled';
  end if;

  if not exists (select 1 from shared.worlds where code = 'WANDERER' and radar_enabled = true and asset_kind = 'MOBILE') then
    raise exception 'WANDERER mobile Radar configuration missing';
  end if;

  if not exists (
    select 1 from land.search_profiles
    where code = 'MONTENEGRO_POD_LAND'
      and development_model = 'POD'
      and price_priority_eur = 15000
      and (criteria ->> 'no_minimum_price')::boolean = true
  ) then
    raise exception 'Montenegro Pod Land Search profile is missing or invalid';
  end if;

  if (select count(*) from land.candidates where internal_name in (
    'pod-pisce-piva', 'pod-vladimir-sasko', 'pod-rudnica-piva', 'pod-rvasi-skadar', 'pod-brijeg-tara'
  ) and development_model = 'POD') <> 5 then
    raise exception 'The five initial Pod hunt candidates were not loaded';
  end if;

  if (select count(*) from land.world_score_criteria c join shared.worlds w on w.id = c.world_id where w.code = 'GREENHILL') = 0
    or (select count(*) from land.world_gate_definitions g join shared.worlds w on w.id = g.world_id where w.code = 'GREENHILL') = 0 then
    raise exception 'GREENHILL lacks land criteria or gate definitions';
  end if;

  if (select count(*) from land.world_gate_definitions g join shared.worlds w on w.id = g.world_id where w.id = floating_world_id and g.code in (
    'floating_ownership', 'registration', 'berth_right', 'commercial_use', 'water_envelope',
    'moorings', 'shore_access', 'emergency_access', 'wastewater'
  )) <> 9 then
    raise exception 'RAFTER lacks its required floating/water gate template';
  end if;

  foreach entity_name in array universe_entities loop
    if to_regclass('universe.' || entity_name) is null then
      raise exception 'Missing Universe V0 entity: %', entity_name;
    end if;
  end loop;

  foreach entity_name in array passport_entities loop
    if to_regclass('passport.' || entity_name) is null then
      raise exception 'Missing Passport V0 entity: %', entity_name;
    end if;
  end loop;

  if not exists (
    select 1
    from universe.nodes n
    join shared.worlds w on w.id = n.world_id
    where w.code = 'GREENHILL' and n.code = 'N.01' and n.node_type = 'stay'
  ) then
    raise exception 'GREENHILL N.01 Universe V0 node missing';
  end if;

  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'universe' and c.relname = any(universe_entities) and c.relrowsecurity)
      <> array_length(universe_entities, 1) then
    raise exception 'RLS is not enabled on every Universe V0 table';
  end if;

  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'passport' and c.relname = any(passport_entities) and c.relrowsecurity)
      <> array_length(passport_entities, 1) then
    raise exception 'RLS is not enabled on every Passport V0 table';
  end if;

  if has_schema_privilege('anon', 'universe', 'USAGE')
     or has_schema_privilege('authenticated', 'universe', 'USAGE')
     or has_schema_privilege('anon', 'passport', 'USAGE')
     or has_schema_privilege('authenticated', 'passport', 'USAGE') then
    raise exception 'Universe/Passport V0 schemas must remain private from anon/authenticated';
  end if;

  if not exists (select 1 from storage.buckets where id = 'compass-evidence' and public = false) then
    raise exception 'compass-evidence bucket is missing or public';
  end if;

  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'shared' and c.relname = any(shared_entities) and c.relrowsecurity) <> array_length(shared_entities, 1) then
    raise exception 'RLS is not enabled on every shared application table';
  end if;

  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'land' and c.relname = any(land_entities) and c.relrowsecurity) <> array_length(land_entities, 1) then
    raise exception 'RLS is not enabled on every land application table';
  end if;
end;
$$;

rollback;
