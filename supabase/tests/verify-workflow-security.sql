begin;

do $$
declare
  owner_id uuid := '00000000-0000-4000-8000-000000000001';
  admin_id uuid := '00000000-0000-4000-8000-000000000005';
  analyst_id uuid := '00000000-0000-4000-8000-000000000002';
  advisor_id uuid := '00000000-0000-4000-8000-000000000003';
  viewer_id uuid := '00000000-0000-4000-8000-000000000004';
begin
  insert into auth.users (
    instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
    confirmation_token, email_change, email_change_token_new, recovery_token
  ) values
    ('00000000-0000-0000-0000-000000000000', owner_id, 'authenticated', 'authenticated', 'owner@test.outland', crypt('test-password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', admin_id, 'authenticated', 'authenticated', 'admin@test.outland', crypt('test-password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', analyst_id, 'authenticated', 'authenticated', 'analyst@test.outland', crypt('test-password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', advisor_id, 'authenticated', 'authenticated', 'advisor@test.outland', crypt('test-password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', ''),
    ('00000000-0000-0000-0000-000000000000', viewer_id, 'authenticated', 'authenticated', 'viewer@test.outland', crypt('test-password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '', '', '', '')
  on conflict (id) do nothing;

  insert into shared.user_roles(user_id, role) values
    (owner_id, 'OWNER'), (admin_id, 'ADMIN'), (analyst_id, 'ANALYST'), (advisor_id, 'ADVISOR'), (viewer_id, 'VIEWER')
  on conflict do nothing;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);

do $$
declare
  greenhill_id uuid;
  riverkeeper_id uuid;
  v_signal_id uuid;
  v_candidate_id uuid;
  v_river_signal_id uuid;
  v_river_candidate_id uuid;
  v_evaluation_id uuid;
  snapshot_weight numeric;
  expected_score numeric;
  actual_score numeric;
  actual_confidence numeric;
begin
  select id into greenhill_id from shared.worlds where code = 'GREENHILL';
  select id into riverkeeper_id from shared.worlds where code = 'RIVERKEEPER';

  insert into land.signals(world_id, source_name, source_url, raw_title, raw_description, raw_price, raw_currency, raw_area_m2)
  values (greenhill_id, 'workflow test', 'https://example.test/signal-promotion', 'Promotion test', 'Test signal', 100000, 'EUR', 10000)
  returning id into v_signal_id;
  v_candidate_id := public.promote_signal_to_candidate(v_signal_id, greenhill_id, null);

  if not exists (select 1 from land.candidates where id = v_candidate_id)
    or not exists (select 1 from land.signals where id = v_signal_id and status = 'PROMOTED' and promoted_candidate_id = v_candidate_id)
    or not exists (select 1 from land.candidate_sources where candidate_id = v_candidate_id and signal_id = v_signal_id)
    or not exists (select 1 from land.candidate_price_history where candidate_id = v_candidate_id and price = 100000)
    or not exists (select 1 from land.candidate_gates where candidate_id = v_candidate_id) then
    raise exception 'Signal promotion verification failed';
  end if;

  v_evaluation_id := public.start_evaluation(v_candidate_id);
  if not exists (select 1 from land.evaluation_dimension_weights where evaluation_id = v_evaluation_id)
    or not exists (select 1 from land.evaluation_items where evaluation_id = v_evaluation_id) then
    raise exception 'Evaluation snapshot was not initialized';
  end if;

  select item_weight into snapshot_weight from land.evaluation_items where evaluation_id = v_evaluation_id and criterion_code = 'natural_beauty';
  update land.world_score_criteria set item_weight = item_weight + 0.5 where world_id = greenhill_id and code = 'natural_beauty';
  if (select item_weight from land.evaluation_items where evaluation_id = v_evaluation_id and criterion_code = 'natural_beauty') <> snapshot_weight then
    raise exception 'Evaluation changed after world configuration changed';
  end if;

  update land.evaluation_items set score = null, confidence_percent = 0, evidence_state = 'UNKNOWN' where evaluation_id = v_evaluation_id;
  update land.evaluation_items set score = 90, confidence_percent = 100, evidence_state = 'VERIFIED' where evaluation_id = v_evaluation_id and criterion_code = 'natural_beauty';
  update land.evaluation_items set score = 92, confidence_percent = 100, evidence_state = 'VERIFIED' where evaluation_id = v_evaluation_id and criterion_code = 'privacy';

  select round(sum(score::numeric * item_weight) / sum(item_weight), 1) into expected_score
  from land.evaluation_items where evaluation_id = v_evaluation_id and dimension = 'PLACE' and score is not null;
  select dimension_score, dimension_confidence into actual_score, actual_confidence
  from land.v_evaluation_dimension_scores where evaluation_id = v_evaluation_id and dimension = 'PLACE';
  if actual_score <> expected_score or actual_confidence >= 100 then
    raise exception 'UNKNOWN was scored as zero or did not reduce confidence';
  end if;

  update land.evaluation_items set score = 95, confidence_percent = 100, evidence_state = 'VERIFIED' where evaluation_id = v_evaluation_id;
  update land.candidate_gates set state = 'FAIL' where id = (
    select id from land.candidate_gates where candidate_id = v_candidate_id and is_critical order by id limit 1
  );
  if (select recommendation from land.v_candidate_radar where id = v_candidate_id) <> 'BLOCKED' then
    raise exception 'Critical failed gate did not block candidate';
  end if;

  insert into land.signals(world_id, source_name, source_url, raw_title, extracted_payload)
  values (riverkeeper_id, 'workflow test', 'https://example.test/riverkeeper', 'Riverkeeper test', '{"asset_kind":"FLOATING"}')
  returning id into v_river_signal_id;
  v_river_candidate_id := public.promote_signal_to_candidate(v_river_signal_id, riverkeeper_id, null);
  if (select count(*) from land.candidate_gates where candidate_id = v_river_candidate_id and gate_code in (
    'floating_ownership', 'registration', 'berth_right', 'commercial_use', 'water_envelope',
    'moorings', 'shore_access', 'emergency_access', 'wastewater'
  )) <> 9 then
    raise exception 'RIVERKEEPER gate template verification failed';
  end if;
end;
$$;

set local role authenticated;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000004', true);
do $$
declare
  affected_rows integer;
begin
  if current_user <> 'authenticated'
    or auth.uid() <> '00000000-0000-4000-8000-000000000004'::uuid
    or not public.can_read()
    or public.can_analyze()
    or public.can_contribute_evidence()
    or public.can_admin() then
    raise exception 'VIEWER authentication context or role helpers are incorrect';
  end if;

  update land.candidates set title = title where id = (select id from land.candidates limit 1);
  get diagnostics affected_rows = row_count;
  if affected_rows > 0 then
    raise exception 'VIEWER unexpectedly modified a candidate';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000002', true);
do $$
declare
  world_id uuid;
  v_candidate_id uuid;
begin
  if current_user <> 'authenticated'
    or auth.uid() <> '00000000-0000-4000-8000-000000000002'::uuid
    or not public.can_analyze()
    or not public.can_contribute_evidence()
    or public.can_admin() then
    raise exception 'ANALYST authentication context or role helpers are incorrect';
  end if;

  select id into world_id from shared.worlds where code = 'GREENHILL';
  select id into v_candidate_id from land.candidates limit 1;
  insert into land.signals(world_id, source_name, source_url, raw_title)
  values (world_id, 'security test', 'https://example.test/analyst', 'Analyst write');
  update land.candidate_gates set notes = 'Analyst update' where id = (select id from land.candidate_gates g where g.candidate_id = v_candidate_id limit 1);
  insert into land.dd_items(candidate_id, category, title) values (v_candidate_id, 'SECURITY', 'Analyst DD write');
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000003', true);
do $$
declare
  v_candidate_id uuid;
  affected_rows integer;
begin
  if current_user <> 'authenticated'
    or auth.uid() <> '00000000-0000-4000-8000-000000000003'::uuid
    or public.can_analyze()
    or not public.can_contribute_evidence()
    or public.can_admin() then
    raise exception 'ADVISOR authentication context or role helpers are incorrect';
  end if;

  select id into v_candidate_id from land.candidates limit 1;
  insert into land.notes(candidate_id, body) values (v_candidate_id, 'Advisor note');
  insert into land.evidence_items(candidate_id, evidence_type, title) values (v_candidate_id, 'OTHER', 'Advisor evidence');
  update land.candidates set title = title where id = v_candidate_id;
  get diagnostics affected_rows = row_count;
  if affected_rows > 0 then
    raise exception 'ADVISOR unexpectedly modified candidate core data';
  end if;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000001', true);
do $$
declare
  v_candidate_id uuid;
  world_id uuid;
begin
  if current_user <> 'authenticated'
    or auth.uid() <> '00000000-0000-4000-8000-000000000001'::uuid
    or not public.can_analyze()
    or not public.can_contribute_evidence()
    or not public.can_admin() then
    raise exception 'OWNER authentication context or role helpers are incorrect';
  end if;

  select id into v_candidate_id from land.candidates limit 1;
  select id into world_id from shared.worlds where code = 'GREENHILL';
  update shared.worlds set search_notes = coalesce(search_notes, '') where id = world_id;
  insert into shared.assets(source_candidate_id, world_id, name, asset_kind) values (v_candidate_id, world_id, 'Owner verification asset', 'LAND');
  insert into shared.user_roles(user_id, role) values ('00000000-0000-4000-8000-000000000004', 'ADVISOR') on conflict do nothing;
end;
$$;

select set_config('request.jwt.claim.sub', '00000000-0000-4000-8000-000000000005', true);
do $$
begin
  if current_user <> 'authenticated'
    or auth.uid() <> '00000000-0000-4000-8000-000000000005'::uuid
    or not public.can_analyze()
    or not public.can_contribute_evidence()
    or not public.can_admin() then
    raise exception 'ADMIN authentication context or role helpers are incorrect';
  end if;

  update shared.worlds set search_notes = coalesce(search_notes, '') where code = 'GREENHILL';
  insert into shared.user_roles(user_id, role) values ('00000000-0000-4000-8000-000000000004', 'ADMIN') on conflict do nothing;
end;
$$;

rollback;
