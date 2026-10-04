-- Disposable local CI only. All diagnostic writes are rolled back.
begin;
do $$
declare
  v_world uuid;
  v_owner uuid := '00000000-0000-4000-8000-000000000001';
  v_candidate uuid;
  v_signal uuid;
  v_promoted uuid;
  v_count bigint;
  v_promoted_world uuid;
begin
  select id into v_world from shared.worlds where code='GREENHILL';
  if v_world is null then raise exception 'GREENHILL world fixture missing'; end if;
  insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,email_change,email_change_token_new,recovery_token)
  values ('00000000-0000-0000-0000-000000000000',v_owner,'authenticated','authenticated','diagnostic-owner@test.outland',crypt('diagnostic',gen_salt('bf')),now(),'{"provider":"email","providers":["email"]}','{}',now(),now(),'','','','') on conflict(id) do nothing;
  insert into shared.user_roles(user_id,role) values(v_owner,'OWNER') on conflict do nothing;
  perform set_config('request.jwt.claim.sub',v_owner::text,true);
  insert into land.candidates(world_id,title,asset_kind,created_by) values(v_world,'CI diagnostic direct','LAND',v_owner) returning id into v_candidate;
  select count(*) into v_count from land.candidates where id=v_candidate;
  raise notice 'Direct insert: candidate visible %, can_analyze %',v_count,public.can_analyze();
  if v_count<>1 then raise exception 'Direct candidate lookup failed'; end if;
  perform public.initialize_candidate_gates(v_candidate);
  raise notice 'Direct candidate gate initialization succeeded';
  insert into land.signals(world_id,source_name,source_url,raw_title,raw_description,raw_price,raw_currency,raw_area_m2)
  values(v_world,'CI promotion diagnostic','https://example.test/diagnostic-promotion','Diagnostic promotion','Isolated CI fixture',100000,'EUR',10000)
  returning id into v_signal;
  begin
    v_promoted := public.promote_signal_to_candidate(v_signal,v_world,null);
    select world_id into v_promoted_world from land.candidates where id=v_promoted;
    raise notice 'Promotion returned %, candidate world %, expected world %',v_promoted,v_promoted_world,v_world;
    if v_promoted_world is distinct from v_world then raise exception 'Promotion returned missing or incorrect candidate'; end if;
  exception when others then
    raise notice 'Promotion failed: SQLSTATE %, message %',SQLSTATE,SQLERRM;
    raise;
  end;
end;
$$;
rollback;
