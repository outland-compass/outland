-- Disposable/local-only Player completion V2 transaction + rollback proof.
-- Never run against production. All synthetic rows are rolled back.
begin;

insert into auth.users(id,instance_id,aud,role,email,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values ('ed100000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000',
  'authenticated','authenticated','sideworld-completion-fixture@example.invalid',
  '{}'::jsonb,'{}'::jsonb,now(),now());

insert into universe.universes(id,slug,name,status,visibility)
values ('ed200000-0000-4000-8000-000000000001','sw-completion-fixture',
  'Completion SQL Fixture','draft','private');

insert into canon.franchises(id,universe_id,slug,name)
values ('ed300000-0000-4000-8000-000000000001',
  'ed200000-0000-4000-8000-000000000001','sw-completion-fixture','Completion SQL Fixture');

insert into canon.series(id,franchise_id,slug,name)
values ('ed400000-0000-4000-8000-000000000001',
  'ed300000-0000-4000-8000-000000000001','sw-completion-fixture','Completion SQL Fixture');

insert into geo.countries(code,name) values ('ZZ','Synthetic Player QA Country')
on conflict(code) do nothing;

insert into geo.cities(id,country_code,slug,name,timezone,default_locale)
values ('ed500000-0000-4000-8000-000000000001',
  'ZZ','sw-completion-fixture','Synthetic Completion City','UTC','en');

insert into canon.quest_drafts(id,universe_id,franchise_id,series_id,city_id,
  created_by,request_key,input_snapshot,status,revision)
values ('ed600000-0000-4000-8000-000000000001',
  'ed200000-0000-4000-8000-000000000001',
  'ed300000-0000-4000-8000-000000000001',
  'ed400000-0000-4000-8000-000000000001',
  'ed500000-0000-4000-8000-000000000001',
  'ed100000-0000-4000-8000-000000000001',
  'ed700000-0000-4000-8000-000000000001',
  '{"testOnly":true}'::jsonb,'draft',1);

insert into canon.quest_draft_revisions(draft_id,revision,document,diagnostics,edited_by)
values('ed600000-0000-4000-8000-000000000001',1,
  '{"contractVersion":"1","testOnly":true}'::jsonb,'[]'::jsonb,
  'ed100000-0000-4000-8000-000000000001');

insert into canon.quest_releases(id,source_draft_id,source_revision,document,
  engine_content_hash,created_by)
values ('ed800000-0000-4000-8000-000000000001',
  'ed600000-0000-4000-8000-000000000001',1,
  '{"contractVersion":"1","testOnly":true}'::jsonb,
  repeat('a',64),'ed100000-0000-4000-8000-000000000001');

insert into player.qa_access(release_id,actor_id,expires_at,granted_by)
values('ed800000-0000-4000-8000-000000000001',
  'ed100000-0000-4000-8000-000000000001',
  now()+interval '2 hours','ed100000-0000-4000-8000-000000000001');

do $completion$
declare
  actor_id uuid := 'ed100000-0000-4000-8000-000000000001';
  other_id uuid := 'ed100000-0000-4000-8000-000000000002';
  release_id uuid := 'ed800000-0000-4000-8000-000000000001';
  start_id uuid := 'ed900000-0000-4000-8000-000000000001';
  nonterminal_id uuid := 'ed900000-0000-4000-8000-000000000002';
  terminal_id uuid := 'ed900000-0000-4000-8000-000000000003';
  extra_id uuid := 'ed900000-0000-4000-8000-000000000004';
  v_run_id uuid;
  initial_progress jsonb;
  first_progress jsonb;
  final_progress jsonb;
  out jsonb;
begin
  initial_progress:=jsonb_build_object(
    'engineVersion',1,'questId','ed600000-0000-4000-8000-000000000001',
    'revision',1,'contentHash',repeat('a',64),'sequence',0,'events','[]'::jsonb);
  out:=public.sideworld_player_run_start_v1(actor_id,release_id,start_id,initial_progress);
  if out->>'kind'<>'started' or out->>'status'<>'in_progress' then
    raise exception 'Completion fixture start failed: %',out;
  end if;
  v_run_id:=(out->>'runId')::uuid;

  first_progress:=initial_progress ||
    jsonb_build_object('sequence',1,'events',
      jsonb_build_array(jsonb_build_object('type','arrive')));
  if public.sideworld_player_run_apply_v2(actor_id,v_run_id,nonterminal_id,
      repeat('b',64),0,first_progress,null)->>'kind'<>'invalid' then
    raise exception 'Null terminal bit must fail closed';
  end if;
  out:=public.sideworld_player_run_apply_v2(actor_id,v_run_id,nonterminal_id,
    repeat('b',64),0,first_progress,false);
  if out->>'kind'<>'saved' or out->>'status'<>'in_progress' then
    raise exception 'Nonterminal V2 command failed: %',out;
  end if;

  final_progress:=initial_progress ||
    jsonb_build_object('sequence',2,'events',
      jsonb_build_array(jsonb_build_object('type','arrive'),
        jsonb_build_object('type','continue')));
  out:=public.sideworld_player_run_apply_v2(actor_id,v_run_id,terminal_id,
    repeat('c',64),1,final_progress,true);
  if out->>'kind'<>'saved' or out->>'status'<>'completed'
    or out->'sequence' <> '2'::jsonb then
    raise exception 'Atomic terminal V2 command failed: %',out;
  end if;
  if not exists(select 1 from player.quest_runs where id=v_run_id
      and status='completed' and sequence=2 and progress=final_progress) then
    raise exception 'Terminal status not persisted with progress';
  end if;

  out:=public.sideworld_player_run_apply_v2(actor_id,v_run_id,terminal_id,
    repeat('c',64),1,final_progress,true);
  if out->>'kind'<>'duplicate' or out->>'status'<>'completed' then
    raise exception 'Retry after completion must remain idempotent: %',out;
  end if;
  if public.sideworld_player_run_apply_v2(actor_id,v_run_id,terminal_id,
      repeat('d',64),1,final_progress,true)->>'kind'<>'conflict' then
    raise exception 'RequestId reused with different fingerprint';
  end if;
  if public.sideworld_player_run_apply_v1(actor_id,v_run_id,extra_id,
      repeat('e',64),2,final_progress)->>'kind'<>'conflict' then
    raise exception 'Legacy V1 must not advance a completed run';
  end if;
  if public.sideworld_player_run_apply_v2(other_id,v_run_id,extra_id,
      repeat('e',64),2,final_progress,true)->>'kind'<>'unavailable' then
    raise exception 'Other actor must not complete this run';
  end if;
  if (select count(*) from player.run_receipts where run_id=v_run_id)<>2 then
    raise exception 'Completion retry generated an extra receipt';
  end if;
  if public.sideworld_player_run_get_v1(actor_id,v_run_id)->>'status'<>'completed' then
    raise exception 'Existing V1 read must expose completed status to trusted server';
  end if;
end $completion$;

rollback;
