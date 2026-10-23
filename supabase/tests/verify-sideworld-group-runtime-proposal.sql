-- Disposable OUTLAND database ONLY. Execute after all real migrations + the
-- proposed group SQL, inside one outer BEGIN/ROLLBACK transaction.
-- Synthetic actors/places, no production user data and no persisted fixtures.

insert into auth.users(id,instance_id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('ce100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','sw-group-host@example.invalid','{}'::jsonb,'{}'::jsonb,now(),now()),
 ('ce100000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','sw-group-partner@example.invalid','{}'::jsonb,'{}'::jsonb,now(),now()),
 ('ce100000-0000-4000-8000-000000000003','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','sw-group-stranger@example.invalid','{}'::jsonb,'{}'::jsonb,now(),now());

insert into universe.universes(id,slug,name,status,visibility)
values ('ce200000-0000-4000-8000-000000000001','sw-group-fixture',
        'Synthetic Group Universe','draft','private');
insert into canon.franchises(id,universe_id,slug,name)
values ('ce300000-0000-4000-8000-000000000001',
        'ce200000-0000-4000-8000-000000000001','sw-group-fixture','Synthetic Group Franchise');
insert into canon.series(id,franchise_id,slug,name)
values ('ce400000-0000-4000-8000-000000000001',
        'ce300000-0000-4000-8000-000000000001','sw-group-fixture','Synthetic Group Series');
insert into geo.countries(code,name) values ('ZZ','Synthetic Group Country')
  on conflict(code) do nothing;
insert into geo.cities(id,country_code,slug,name,timezone,default_locale)
values ('ce500000-0000-4000-8000-000000000001','ZZ',
        'sw-group-fixture','Synthetic Group City','UTC','en');
insert into canon.quest_drafts(id,universe_id,franchise_id,series_id,city_id,
  created_by,request_key,input_snapshot,status,revision)
values ('ce600000-0000-4000-8000-000000000001',
  'ce200000-0000-4000-8000-000000000001',
  'ce300000-0000-4000-8000-000000000001',
  'ce400000-0000-4000-8000-000000000001',
  'ce500000-0000-4000-8000-000000000001',
  'ce100000-0000-4000-8000-000000000001',
  'ce700000-0000-4000-8000-000000000001',
  '{"testOnly":true}'::jsonb,'draft',1);
insert into canon.quest_draft_revisions(draft_id,revision,document,diagnostics,edited_by)
values ('ce600000-0000-4000-8000-000000000001',1,
  '{"contractVersion":1,"testOnly":true}'::jsonb,'[]'::jsonb,
  'ce100000-0000-4000-8000-000000000001');

insert into canon.quest_releases(id,source_draft_id,source_revision,document,engine_content_hash,created_by)
values ('ce800000-0000-4000-8000-000000000001',
  'ce600000-0000-4000-8000-000000000001',1,
  jsonb_build_object(
    'contractVersion',1,'experienceModes',
      jsonb_build_object('version',1,'couple',jsonb_build_object(
        'minPlayers',2,'maxPlayers',2,
        'roles',jsonb_build_array(
          jsonb_build_object('id','observer','label','Observer'),
          jsonb_build_object('id','decoder','label','Decoder')),
        'roleClues',jsonb_build_array(
          jsonb_build_object('puzzleId','synthetic-puzzle','roleId','observer','text','observer-only'),
          jsonb_build_object('puzzleId','synthetic-puzzle','roleId','decoder','text','decoder-only'))))),
  repeat('a',64),'ce100000-0000-4000-8000-000000000001');

insert into player.qa_access(release_id,actor_id,expires_at,granted_by)
values
 ('ce800000-0000-4000-8000-000000000001',
  'ce100000-0000-4000-8000-000000000001',
  now()+interval '2 hours','ce100000-0000-4000-8000-000000000001'),
 ('ce800000-0000-4000-8000-000000000001',
  'ce100000-0000-4000-8000-000000000002',
  now()+interval '2 hours','ce100000-0000-4000-8000-000000000001');

do $group_test$
declare
  host uuid := 'ce100000-0000-4000-8000-000000000001';
  partner uuid := 'ce100000-0000-4000-8000-000000000002';
  stranger uuid := 'ce100000-0000-4000-8000-000000000003';
  release uuid := 'ce800000-0000-4000-8000-000000000001';
  start_key uuid := 'ce900000-0000-4000-8000-000000000001';
  action_key uuid := 'ce900000-0000-4000-8000-000000000002';
  competing_key uuid := 'ce900000-0000-4000-8000-000000000003';
  session uuid;
  res jsonb;
  initial jsonb;
  next jsonb;
begin
  initial := jsonb_build_object('engineVersion',1,
    'questId','ce600000-0000-4000-8000-000000000001',
    'revision',1,'contentHash',repeat('a',64),
    'sequence',0,'events','[]'::jsonb);
  res := public.sideworld_group_create_v1(stranger,release,'couple',start_key,
    initial,repeat('b',64),now()+interval '30 minutes');
  if res->>'kind' <> 'unavailable' then
    raise exception 'Unentitled stranger created group: %',res;
  end if;
  res := public.sideworld_group_create_v1(host,release,'couple',start_key,
    initial,repeat('b',64),now()+interval '30 minutes');
  if res->>'kind' <> 'started' or res->'new' is distinct from 'true'::jsonb
       or res->'expectedPlayers' is distinct from '2'::jsonb
       or res->>'status' <> 'forming' then
    raise exception 'Group create failed: %',res;
  end if;
  session := (res->>'sessionId')::uuid;
  if session is null then raise exception 'No group session id'; end if;
  res := public.sideworld_group_create_v1(host,release,'couple',start_key,
    initial,repeat('c',64),now()+interval '30 minutes');
  if res->>'kind' <> 'started' or res->'new' is distinct from 'false'::jsonb
       or (res->>'sessionId')::uuid <> session then
    raise exception 'Create retry not idempotent: %',res;
  end if;
  if (select count(*) from player.group_members where session_id=session) <> 1 then
    raise exception 'Host not assigned exactly one role';
  end if;
  if public.sideworld_group_get_v1(stranger,session) is not null then
    raise exception 'Nonmember read group progress';
  end if;
  if public.sideworld_group_join_v1(partner,session,repeat('c',64))->>'kind'
        <> 'unavailable' then
    raise exception 'Invalid invite hash accepted';
  end if;
  if public.sideworld_group_join_v1(stranger,session,repeat('b',64))->>'kind'
        <> 'unavailable' then
    raise exception 'Unentitled actor used valid invite';
  end if;
  res := public.sideworld_group_join_v1(partner,session,repeat('b',64));
  if res->>'kind' <> 'joined' or res->>'roleId' <> 'decoder'
       or res->>'status' <> 'in_progress' then
    raise exception 'Partner join/unique role failed: %',res;
  end if;
  if public.sideworld_group_join_v1(partner,session,repeat('b',64))->>'roleId'
        <> 'decoder' then
    raise exception 'Partner idempotent join failed';
  end if;
  if public.sideworld_group_get_v1(partner,session)->>'roleId'
        <> 'decoder' then
    raise exception 'Actor-specific role projection wrong';
  end if;
  if public.sideworld_group_receipt_get_v1(partner,session,action_key) is not null then
    raise exception 'Nonexistent receipt was returned';
  end if;

  next := initial || jsonb_build_object('sequence',1,
    'events',jsonb_build_array(jsonb_build_object('type','arrive')));
  res := public.sideworld_group_apply_v1(host,session,action_key,
    repeat('d',64),0,next,false);
  if res->>'kind' <> 'saved' or res->'resultSequence' is distinct from '1'::jsonb then
    raise exception 'Atomic group transition failed: %',res;
  end if;
  if public.sideworld_group_receipt_get_v1(host,session,action_key)->>'fingerprint'
       <> repeat('d',64) then
    raise exception 'Receipt missing/incorrect';
  end if;
  if public.sideworld_group_receipt_get_v1(partner,session,action_key) is not null then
    raise exception 'Actor can read another member receipt';
  end if;
  if public.sideworld_group_apply_v1(host,session,action_key,
       repeat('d',64),0,next,false)->>'kind' <> 'duplicate' then
    raise exception 'Identical committed retry was not idempotent';
  end if;
  if public.sideworld_group_apply_v1(host,session,action_key,
       repeat('e',64),0,next,false)->>'kind' <> 'conflict' then
    raise exception 'Changed payload reused committed id';
  end if;
  if public.sideworld_group_apply_v1(partner,session,action_key,
       repeat('d',64),0,next,false)->>'kind' <> 'conflict' then
    raise exception 'Cross-actor request ID collision was not denied';
  end if;
  if public.sideworld_group_apply_v1(partner,session,competing_key,
       repeat('e',64),0,next,false)->>'kind' <> 'conflict' then
    raise exception 'Stale member sequence unexpectedly committed';
  end if;
  if (select count(*) from player.group_receipts where session_id=session) <> 1 then
    raise exception 'Conflicting action generated extra receipt';
  end if;

  update player.qa_access set revoked_at=now()
    where release_id=release and actor_id=partner;
  if public.sideworld_group_get_v1(partner,session) is not null then
    raise exception 'Revoked member can read group';
  end if;
  if public.sideworld_group_apply_v1(partner,session,competing_key,
       repeat('e',64),1,next,false)->>'kind' <> 'unavailable' then
    raise exception 'Revoked member can commit group action';
  end if;
  if public.sideworld_group_leave_v1(host,session)->>'kind' <> 'left' then
    raise exception 'Host could not leave';
  end if;
  if (select status from player.group_sessions where id=session) <> 'abandoned' then
    raise exception 'Departure did not abandon interrupted session';
  end if;
end
$group_test$;

do $security$
declare
  role_name text;
  table_name text;
  function_signature text;
begin
  foreach role_name in array array['anon','authenticated'] loop
    foreach table_name in array array[
      'player.group_sessions','player.group_members','player.group_receipts'
    ] loop
      if has_table_privilege(role_name,table_name,'SELECT') or
         has_table_privilege(role_name,table_name,'INSERT') or
         has_table_privilege(role_name,table_name,'UPDATE') or
         has_table_privilege(role_name,table_name,'DELETE') then
        raise exception 'Browser role % can access private table %',role_name,table_name;
      end if;
    end loop;
    foreach function_signature in array array[
      'public.sideworld_group_create_v1(uuid,uuid,text,uuid,jsonb,text,timestamptz)',
      'public.sideworld_group_join_v1(uuid,uuid,text)',
      'public.sideworld_group_get_v1(uuid,uuid)',
      'public.sideworld_group_receipt_get_v1(uuid,uuid,uuid)',
      'public.sideworld_group_apply_v1(uuid,uuid,uuid,text,integer,jsonb,boolean)',
      'public.sideworld_group_leave_v1(uuid,uuid)'
    ] loop
      if has_function_privilege(role_name,function_signature,'EXECUTE') then
        raise exception 'Browser role % can execute private RPC %',role_name,function_signature;
      end if;
      if not has_function_privilege('service_role',function_signature,'EXECUTE') then
        raise exception 'service_role lacks approved RPC %',function_signature;
      end if;
    end loop;
  end loop;
  foreach table_name in array array[
    'player.group_sessions','player.group_members','player.group_receipts'
  ] loop
    if not exists (
      select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='player' and c.relname=split_part(table_name,'.',2)
        and c.relrowsecurity and not exists (
          select 1 from pg_policy p where p.polrelid=c.oid
        )
    ) then
      raise exception 'Private table not RLS-locked with zero policies: %',table_name;
    end if;
  end loop;
end
$security$;

select 'PASS: isolated Group SQL, two-actor session, CAS, receipts, entitlement revocation and private grants' as check_result;
