-- Disposable rollback-only integration check for private release editor.
-- Reuse canonical fixture tables and role model from Player transaction tests.
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


insert into shared.user_roles(user_id,role,created_by) values(
 'dd100000-0000-4000-8000-000000000001','OWNER','dd100000-0000-4000-8000-000000000001');

do $qa_editor$
declare
 actor uuid:='dd100000-0000-4000-8000-000000000001';
 release_id uuid:='dd800000-0000-4000-8000-000000000001';
 result jsonb;
begin
 if has_function_privilege('anon','public.sideworld_private_release_editor_get_v1(uuid,uuid)','EXECUTE') or
    has_function_privilege('authenticated','public.sideworld_private_release_editor_save_v1(uuid,uuid,text,jsonb,text)','EXECUTE') or
    not has_function_privilege('service_role','public.sideworld_private_release_editor_save_v1(uuid,uuid,text,jsonb,text)','EXECUTE')
 then raise exception 'Private editor function grant violation'; end if;

 result:=public.sideworld_private_release_editor_get_v1(actor,release_id);
 if result->>'kind'<>'ok' or result->>'contentHash'<>repeat('a',64)
    or result->>'revision'<>'1'
 then raise exception 'Owner cannot read release'; end if;
 if public.sideworld_private_release_editor_get_v1(
   '00000000-0000-4000-8000-000000000009'::uuid,release_id)->>'kind'<>'unavailable'
 then raise exception 'Nonowner can read private release'; end if;

 result:=public.sideworld_private_release_editor_save_v1(actor,release_id,repeat('a',64),
   '{"contractVersion":"1","testOnly":true,"copyEdit":true}'::jsonb,repeat('b',64));
 if result->>'kind'<>'saved' or result->>'contentHash'<>repeat('b',64)
 then raise exception 'Atomic in-place private copy edit refused'; end if;
 if not exists(select 1 from canon.quest_releases where id=release_id
   and source_revision=1 and engine_content_hash=repeat('b',64)
   and document->>'copyEdit'='true')
 then raise exception 'Release identity or hash was changed unexpectedly'; end if;

 result:=public.sideworld_private_release_editor_save_v1(actor,release_id,repeat('a',64),
   '{"contractVersion":"1","testOnly":true,"copyEdit":true}'::jsonb,repeat('c',64));
 if result->>'kind'<>'conflict' then raise exception 'Stale write not rejected'; end if;

 result:=public.sideworld_private_release_editor_save_v1(actor,release_id,repeat('b',64),
   '{"contractVersion":"1","testOnly":true,"copyEdit":true}'::jsonb,repeat('c',64));
 if result->>'kind'<>'invalid' then raise exception 'Hash-only edit not rejected'; end if;

 update canon.quest_releases set visibility='retired' where id=release_id;
 if public.sideworld_private_release_editor_get_v1(actor,release_id)->>'kind'<>'unavailable'
 then raise exception 'Retired content was exposed for editing'; end if;
 if public.sideworld_private_release_editor_save_v1(actor,release_id,repeat('b',64),
   '{"contractVersion":"1","testOnly":true,"copyEdit":false}'::jsonb,repeat('c',64))->>'kind'<>'unavailable'
 then raise exception 'Retired edit was accepted'; end if;
 raise notice 'PASS: private release editor grants, owner check, CAS and retired lockdown';
end $qa_editor$;
rollback;
