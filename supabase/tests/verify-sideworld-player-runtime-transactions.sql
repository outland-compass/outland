-- Local/disposable integration-only SQL proof for SIDEWORLD Player V1.
-- Synthesizes actor/canon/draft/QA/release/run rows inside a ROLLBACK transaction.
-- Not intended for production/staging unless specifically reviewed/approved.
begin;

insert into auth.users(id,instance_id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('dd100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','sideworld-player-db-fixture@example.invalid',
  '{}'::jsonb,'{}'::jsonb,now(),now());

insert into universe.universes(id,slug,name,status,visibility)
values ('dd200000-0000-4000-8000-000000000001','sw-player-db-fixture','Player SQL Fixture','draft','private');

insert into canon.franchises(id,universe_id,slug,name)
values ('dd300000-0000-4000-8000-000000000001',
  'dd200000-0000-4000-8000-000000000001','sw-player-db-fixture','Player SQL Fixture');

insert into canon.series(id,franchise_id,slug,name)
values ('dd400000-0000-4000-8000-000000000001',
  'dd300000-0000-4000-8000-000000000001','sw-player-db-fixture','Player SQL Fixture');

insert into geo.countries(code,name) values ('ZZ','Synthetic Player QA Country')
on conflict(code) do nothing;

insert into geo.cities(id,country_code,slug,name,timezone,default_locale)
values ('dd500000-0000-4000-8000-000000000001','ZZ','sw-player-db-fixture','Synthetic Player City','UTC','en');

insert into canon.quest_drafts(id,universe_id,franchise_id,series_id,city_id,
  created_by,request_key,input_snapshot,status,revision)
values ('dd600000-0000-4000-8000-000000000001',
  'dd200000-0000-4000-8000-000000000001',
  'dd300000-0000-4000-8000-000000000001',
  'dd400000-0000-4000-8000-000000000001',
  'dd500000-0000-4000-8000-000000000001',
  'dd100000-0000-4000-8000-000000000001',
  'dd700000-0000-4000-8000-000000000001',
  '{"testOnly":true}'::jsonb,'draft',1);

insert into canon.quest_draft_revisions(draft_id,revision,document,diagnostics,edited_by)
values('dd600000-0000-4000-8000-000000000001',1,
  '{"contractVersion":"1","testOnly":true}'::jsonb,'[]'::jsonb,
  'dd100000-0000-4000-8000-000000000001');

insert into canon.quest_releases(id,source_draft_id,source_revision,document,
  engine_content_hash,created_by)
values ('dd800000-0000-4000-8000-000000000001',
  'dd600000-0000-4000-8000-000000000001',1,
  '{"contractVersion":"1","testOnly":true}'::jsonb,
  repeat('a',64),'dd100000-0000-4000-8000-000000000001');

insert into player.qa_access(release_id,actor_id,expires_at,granted_by)
values('dd800000-0000-4000-8000-000000000001',
  'dd100000-0000-4000-8000-000000000001',
  now()+interval '2 hours','dd100000-0000-4000-8000-000000000001');

do $test$
declare
  actor_id uuid := 'dd100000-0000-4000-8000-000000000001';
  other_id uuid := 'dd100000-0000-4000-8000-000000000002';
  release_id uuid := 'dd800000-0000-4000-8000-000000000001';
  new_request uuid := 'dd900000-0000-4000-8000-000000000001';
  first_action uuid := 'dd900000-0000-4000-8000-000000000002';
  another_action uuid := 'dd900000-0000-4000-8000-000000000003';
  run_id uuid;
  base_progress jsonb;
  next_progress jsonb;
  tampered_progress jsonb;
  result jsonb;
begin
  if public.sideworld_player_release_get_v1(other_id,release_id) is not null then
    raise exception 'Unentitled actor saw source';
  end if;
  result:=public.sideworld_player_release_get_v1(actor_id,release_id);
  if result->>'visibility' <> 'private_qa'
     or result->>'contentHash' <> repeat('a',64) then
    raise exception 'Authorized release get failed';
  end if;

  begin
    update canon.quest_releases set document='{"contractVersion":"1","changed":true}'::jsonb
    where id=release_id;
    raise exception 'Expected immutable document guard';
  exception when raise_exception then
    if sqlerrm <> 'Quest release content and source are immutable' then raise; end if;
  end;

  begin
    update canon.quest_releases set visibility='published' where id=release_id;
    raise exception 'Expected publication approval gate';
  exception when check_violation then null;
  end;

  base_progress:=jsonb_build_object(
    'engineVersion',1,'questId','dd600000-0000-4000-8000-000000000001',
    'revision',1,'contentHash',repeat('a',64),'sequence',0,'events','[]'::jsonb);
  result:=public.sideworld_player_run_start_v1(actor_id,release_id,new_request,base_progress);
  if result->>'kind' <> 'started' or result->>'accessMode'<>'private_qa'
     or result->'progress' is distinct from base_progress then
    raise exception 'Initial trusted run creation failed: %',result;
  end if;
  run_id:=(result->>'runId')::uuid;
  if run_id is null then raise exception 'No runId'; end if;
  if public.sideworld_player_run_start_v1(actor_id,release_id,new_request,base_progress)->>'runId'
       is distinct from run_id::text then
    raise exception 'Idempotent start generated another run';
  end if;
  if public.sideworld_player_run_get_v1(other_id,run_id) is not null then
    raise exception 'Cross-actor run leak';
  end if;
  if public.sideworld_player_run_receipt_get_v1(actor_id,run_id,first_action) is not null then
    raise exception 'Receipt exists before action';
  end if;

  next_progress:=base_progress ||
    jsonb_build_object('sequence',1,'events',
      jsonb_build_array(jsonb_build_object('type','arrive')));
  result:=public.sideworld_player_run_apply_v1(actor_id,run_id,first_action,
    repeat('b',64),0,next_progress);
  if result->>'kind'<>'saved' or result->'sequence' <> '1'::jsonb then
    raise exception 'Atomic CAS update failed: %',result;
  end if;
  result:=public.sideworld_player_run_apply_v1(actor_id,run_id,first_action,
    repeat('b',64),0,next_progress);
  if result->>'kind'<>'duplicate' or result->'sequence'<>'1'::jsonb then
    raise exception 'Idempotent action retry was not returned: %',result;
  end if;
  result:=public.sideworld_player_run_receipt_get_v1(actor_id,run_id,first_action);
  if result->>'fingerprint' <> repeat('b',64)
    or result->'progress' is distinct from next_progress then
    raise exception 'Receipt mismatch';
  end if;
  if public.sideworld_player_run_apply_v1(actor_id,run_id,first_action,
      repeat('c',64),0,next_progress)->>'kind' <> 'conflict' then
    raise exception 'Reused requestId with different body was not rejected';
  end if;
  if public.sideworld_player_run_apply_v1(actor_id,run_id,another_action,
      repeat('d',64),0,next_progress)->>'kind' <> 'conflict' then
    raise exception 'Stale sequence unexpectedly advanced';
  end if;

  tampered_progress:=base_progress ||
    jsonb_build_object('sequence',2,'events',
      jsonb_build_array(jsonb_build_object('type','forged'),
        jsonb_build_object('type','arrive')));
  if public.sideworld_player_run_apply_v1(actor_id,run_id,another_action,
      repeat('d',64),1,tampered_progress)->>'kind' <> 'invalid' then
    raise exception 'History prefix tampering accepted';
  end if;

  update player.qa_access q set revoked_at=now()
  where q.release_id='dd800000-0000-4000-8000-000000000001'::uuid
    and q.actor_id='dd100000-0000-4000-8000-000000000001'::uuid;
  if public.sideworld_player_run_get_v1(actor_id,run_id) is not null then
    raise exception 'Revoked QA can still load trusted run';
  end if;
  if public.sideworld_player_run_apply_v1(actor_id,run_id,another_action,
      repeat('d',64),1,next_progress)->>'kind' <> 'unavailable' then
    raise exception 'Revoked QA can still write trusted progress';
  end if;
end
$test$;


-- Additional private-QA operator/release/grant lifecycle checks.
-- This is a second Studio revision in the same synthetic, rolled-back fixture.
insert into auth.users(id,instance_id,aud,role,email,raw_app_meta_data,
                       raw_user_meta_data,created_at,updated_at)
values ('dd100000-0000-4000-8000-000000000002',
        '00000000-0000-0000-0000-000000000000','authenticated',
        'authenticated','sideworld-player-ordinary-fixture@example.invalid',
        '{}'::jsonb,'{}'::jsonb,now(),now());
insert into shared.user_roles(user_id,role,created_by)
values('dd100000-0000-4000-8000-000000000001','OWNER',
       'dd100000-0000-4000-8000-000000000001');

insert into canon.quest_draft_revisions(draft_id,revision,document,diagnostics,edited_by)
values('dd600000-0000-4000-8000-000000000001',2,
       '{"contractVersion":1,"testOnly":true,"secondRevision":true}'::jsonb,
       '[]'::jsonb,'dd100000-0000-4000-8000-000000000001');
update canon.quest_drafts set revision=2,status='draft'
where id='dd600000-0000-4000-8000-000000000001';

do $qa$
declare
  owner_id uuid:='dd100000-0000-4000-8000-000000000001';
  tester_id uuid:='dd100000-0000-4000-8000-000000000002';
  draft_id uuid:='dd600000-0000-4000-8000-000000000001';
  result jsonb;
  release_id uuid;
begin
  if player.is_qa_operator_v1(tester_id) then
    raise exception 'Ordinary tester recognized as Studio admin';
  end if;
  if public.sideworld_player_qa_release_create_v1(
      tester_id,draft_id,2,repeat('c',64))->>'kind'<>'unavailable' then
    raise exception 'Non-admin operator created release';
  end if;
  result:=public.sideworld_player_qa_release_create_v1(
      owner_id,draft_id,2,repeat('c',64));
  if result->>'kind'<>'created' then
    raise exception 'Expected new immutable QA release: %',result;
  end if;
  release_id:=(result->>'releaseId')::uuid;
  if release_id is null or not exists(
      select 1 from canon.quest_releases
      where id=release_id and source_revision=2 and visibility='private_qa'
        and document='{"contractVersion":1,"testOnly":true,"secondRevision":true}'::jsonb) then
    raise exception 'QA release was not a frozen Studio revision';
  end if;
  if public.sideworld_player_qa_release_create_v1(
      owner_id,draft_id,2,repeat('c',64))->>'kind'<>'existing' then
    raise exception 'Identical repeated release was not idempotent';
  end if;
  if public.sideworld_player_qa_release_create_v1(
      owner_id,draft_id,2,repeat('d',64))->>'kind'<>'conflict' then
    raise exception 'Release accepted a different content checksum';
  end if;
  if public.sideworld_player_qa_grant_v1(
      owner_id,release_id,tester_id,now()+interval '16 days')->>'kind'<>'invalid' then
    raise exception 'Overlong QA entitlement was accepted';
  end if;
  if public.sideworld_player_qa_grant_v1(
      tester_id,release_id,tester_id,now()+interval '1 hour')->>'kind'<>'unavailable' then
    raise exception 'Ordinary tester granted themselves access';
  end if;
  if public.sideworld_player_qa_grant_v1(
      owner_id,release_id,tester_id,now()+interval '1 hour')->>'kind'<>'granted'
     or not player.can_use_release_v1(tester_id,release_id) then
    raise exception 'Non-admin QA grant failed';
  end if;
  if public.sideworld_player_qa_revoke_v1(
      tester_id,release_id,tester_id)->>'kind'<>'unavailable' then
    raise exception 'Non-admin tester revoked their own grant';
  end if;
  if public.sideworld_player_qa_revoke_v1(
      owner_id,release_id,tester_id)->>'kind'<>'revoked'
     or player.can_use_release_v1(tester_id,release_id) then
    raise exception 'Admin revocation failed to disable QA access';
  end if;
  if public.sideworld_player_qa_revoke_v1(
      owner_id,release_id,tester_id)->>'kind'<>'revoked' then
    raise exception 'Repeated revocation must be idempotent';
  end if;
  if public.sideworld_player_qa_grant_v1(
      owner_id,release_id,tester_id,now()+interval '90 minutes')->>'kind'<>'granted'
     or not player.can_use_release_v1(tester_id,release_id) then
    raise exception 'Renewing a revoked QA grant failed';
  end if;
end $qa$;

rollback;
