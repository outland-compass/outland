-- Disposable local CI only. Diagnose candidate lookup without changing application logic.
begin;
do $$
declare
  v_world uuid;
  v_owner uuid := '00000000-0000-4000-8000-000000000001';
  v_candidate uuid;
  v_count bigint;
begin
  select id into v_world from shared.worlds where code='GREENHILL';
  if v_world is null then raise exception 'GREENHILL world fixture missing'; end if;
  insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,email_change,email_change_token_new,recovery_token)
  values ('00000000-0000-0000-0000-000000000000',v_owner,'authenticated','authenticated','diagnostic-owner@test.outland',crypt('diagnostic',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now(),'','','','') on conflict(id) do nothing;
  insert into shared.user_roles(user_id,role) values(v_owner,'OWNER') on conflict do nothing;
  perform set_config('request.jwt.claim.sub',v_owner::text,true);
  insert into land.candidates(world_id,title,asset_kind,created_by) values(v_world,'CI diagnostic','LAND',v_owner) returning id into v_candidate;
  select count(*) into v_count from land.candidates where id=v_candidate;
  raise notice 'Role %, session_user %, candidate %, direct count %, can_analyze %',current_user,session_user,v_candidate,v_count,public.can_analyze();
  if v_count<>1 then raise exception 'Direct candidate lookup failed'; end if;
  perform public.initialize_candidate_gates(v_candidate);
  raise notice 'initialize_candidate_gates succeeded';
end;
$$;
rollback;
