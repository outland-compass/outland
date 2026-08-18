begin;

do $$
declare
  expected_entities text[] := array[
    'profiles', 'user_roles', 'worlds', 'assets', 'signals', 'candidates',
    'candidate_sources', 'candidate_price_history', 'candidate_media',
    'candidate_economics', 'evaluations', 'evaluation_dimension_weights',
    'evaluation_items', 'candidate_gates', 'dd_items', 'documents',
    'evidence_items', 'notes', 'visits', 'decisions', 'activities'
  ];
  entity_name text;
begin
  foreach entity_name in array expected_entities loop
    if to_regclass('public.' || entity_name) is null then
      raise exception 'Missing public entity: %', entity_name;
    end if;
  end loop;

  foreach entity_name in array array[
    'v_evaluation_dimension_scores', 'v_evaluation_scores',
    'v_candidate_gate_summary', 'v_candidate_latest_evaluation', 'v_candidate_radar'
  ] loop
    if to_regclass('public.' || entity_name) is null then
      raise exception 'Missing read model: %', entity_name;
    end if;
  end loop;

  if (select count(*) from public.worlds where code in (
    'GREENHILL', 'LOST_SIGNAL', 'NAVIGATOR', 'LOST_VALLEY', 'RIVERKEEPER', 'WANDERER'
  )) <> 6 then
    raise exception 'The six required worlds were not seeded';
  end if;

  if not exists (select 1 from public.worlds where code = 'WANDERER' and radar_enabled = false) then
    raise exception 'WANDERER must be seeded with radar_enabled = false';
  end if;

  if (select count(*) from public.world_score_criteria c join public.worlds w on w.id = c.world_id where w.code = 'GREENHILL') = 0
    or (select count(*) from public.world_gate_definitions g join public.worlds w on w.id = g.world_id where w.code = 'GREENHILL') = 0 then
    raise exception 'GREENHILL lacks land criteria or gate definitions';
  end if;

  if (select count(*) from public.world_gate_definitions g join public.worlds w on w.id = g.world_id where w.code = 'RIVERKEEPER' and g.code in (
    'floating_ownership', 'registration', 'berth_right', 'commercial_use', 'water_envelope',
    'moorings', 'shore_access', 'emergency_access', 'wastewater'
  )) <> 9 then
    raise exception 'RIVERKEEPER lacks its required floating/water gate template';
  end if;

  if not exists (select 1 from storage.buckets where id = 'compass-evidence' and public = false) then
    raise exception 'compass-evidence bucket is missing or public';
  end if;

  if (select count(*) from pg_class c join pg_namespace n on n.oid = c.relnamespace where n.nspname = 'public' and c.relname = any(expected_entities) and c.relrowsecurity) <> array_length(expected_entities, 1) then
    raise exception 'RLS is not enabled on every application table';
  end if;
end;
$$;

rollback;
