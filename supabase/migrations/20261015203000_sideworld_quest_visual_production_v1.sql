-- SIDEWORLD Quest Visual Production V1 (ADDITIVE / NOT AUTHORIZED FOR PRODUCTION EXECUTION).
-- Canonical universe/franchise/character/quest identity is referenced, never duplicated.
-- Database/schema owner: OUTLAND. Consumers: SIDEWORLD Studio and SIDEWORLD Player.
-- PR REVIEW ONLY until verified production backup, isolated restore readiness and explicit founder approval.

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('sideworld-quest-media','sideworld-quest-media',false,10485760,
  array['image/png','image/jpeg','image/webp'])
on conflict(id) do nothing;

create table canon.quest_visual_jobs (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null references canon.quest_drafts(id) on delete restrict,
  revision integer not null,
  brief_id text not null check(length(brief_id) between 1 and 128 and brief_id ~ '^[a-z0-9._-]+$'),
  actor_id uuid not null references auth.users(id) on delete restrict,
  request_key uuid not null,
  provider text not null check(provider in ('openai','manual')),
  model text not null check(length(model) between 1 and 120),
  max_cost_usd numeric(9,4) not null check(max_cost_usd>=0 and max_cost_usd<=1),
  actual_cost_usd numeric(9,4) check(actual_cost_usd>=0),
  usage jsonb not null default '{}'::jsonb check(jsonb_typeof(usage)='object'),
  status text not null default 'reserved' check(status in ('reserved','completed','failed')),
  error_code text,
  created_at timestamptz not null default now(),
  finished_at timestamptz,
  foreign key(draft_id,revision) references canon.quest_draft_revisions(draft_id,revision) on delete restrict,
  unique(actor_id,request_key)
);
create unique index quest_visual_one_active_job on canon.quest_visual_jobs(draft_id,revision,brief_id)
  where status='reserved';
create index quest_visual_jobs_by_actor_time on canon.quest_visual_jobs(actor_id,created_at desc);

create table canon.quest_visual_assets (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null,
  revision integer not null,
  brief_id text not null check(length(brief_id) between 1 and 128 and brief_id ~ '^[a-z0-9._-]+$'),
  job_id uuid unique references canon.quest_visual_jobs(id) on delete restrict,
  asset_version integer not null check(asset_version>0),
  visual_role text not null check(visual_role in
    ('cover','scene_backdrop','sketchbook','atlas','puzzle_evidence',
     'notebook_artifact','finale_art','historical_source','location_photo')),
  source_kind text not null check(source_kind in ('ai_illustration','manual_illustration','historical_source','real_photo')),
  storage_bucket text not null default 'sideworld-quest-media' check(storage_bucket='sideworld-quest-media'),
  storage_path text not null unique check(length(storage_path)<=500 and storage_path!~ '(^/|[.][.]|//)'),
  source_sha256 text not null check(source_sha256 ~ '^[a-f0-9]{64}$'),
  mime_type text not null check(mime_type in ('image/png','image/jpeg','image/webp')),
  width integer not null check(width between 128 and 4096),
  height integer not null check(height between 128 and 4096),
  source_ref text,
  provenance jsonb not null default '{}'::jsonb check(jsonb_typeof(provenance)='object'),
  prompt_version text,
  rights_note text not null check(length(btrim(rights_note)) between 20 and 1000),
  approval_status text not null default 'candidate' check(approval_status in ('candidate','approved','rejected','retired')),
  approved_by uuid references auth.users(id) on delete restrict,
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  foreign key(draft_id,revision) references canon.quest_draft_revisions(draft_id,revision) on delete restrict,
  unique(draft_id,revision,brief_id,asset_version),
  constraint quest_visual_approval_consistency check (
    (approval_status in ('approved','retired') and approved_by is not null and approved_at is not null)
    or (approval_status in ('candidate','rejected') and approved_by is null and approved_at is null)
  ),
  constraint quest_visual_real_media_provenance check (
    (visual_role='location_photo' and source_kind='real_photo') or
    (visual_role='historical_source' and source_kind='historical_source') or
    (visual_role not in ('historical_source','location_photo') and
      source_kind in ('ai_illustration','manual_illustration'))
  ),
  constraint quest_visual_private_content_path check (
    storage_path = draft_id::text || '/r' || revision::text || '/' || source_sha256 ||
      case mime_type when 'image/png' then '.png' when 'image/jpeg' then '.jpg' else '.webp' end
  )
);
create index quest_visual_assets_draft on canon.quest_visual_assets(draft_id,revision,created_at desc);
create unique index quest_visual_one_approved_per_brief on canon.quest_visual_assets(draft_id,revision,brief_id)
  where approval_status='approved';

-- Immutable release-bound bindings. Multiple stages can reuse an approved image without duplicating bytes.
create table canon.quest_visual_bindings (
  release_id uuid not null references canon.quest_releases(id) on delete restrict,
  scene_id text not null default '' check(length(scene_id)<=128),
  slot text not null check(slot in ('cover','scene','evidence','notebook','finale')),
  asset_id uuid not null references canon.quest_visual_assets(id) on delete restrict,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key(release_id,scene_id,slot)
);
create index quest_visual_bindings_asset on canon.quest_visual_bindings(asset_id);

alter table canon.quest_visual_jobs enable row level security;
alter table canon.quest_visual_assets enable row level security;
alter table canon.quest_visual_bindings enable row level security;
revoke all on canon.quest_visual_jobs,canon.quest_visual_assets,canon.quest_visual_bindings
  from public,anon,authenticated,service_role;
-- No browser storage.objects policies on sideworld-quest-media.
-- All writes/readback use explicitly granted service-role-only security-definer RPCs and server Storage API.

create function public.sideworld_quest_visual_reserve(
 p_actor uuid,p_draft uuid,p_revision integer,p_brief text,p_request uuid,
 p_provider text,p_model text,p_max_cost_usd numeric
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v_doc jsonb; v_found canon.quest_visual_jobs; v_daily numeric;
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN')) then
   raise exception 'Admin required'; end if;
 if p_request is null or p_provider not in ('openai','manual') or
    length(p_model) not between 1 and 120 or
    p_max_cost_usd < 0 or p_max_cost_usd>1 then
   raise exception 'Invalid generation limits'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_actor::text,7));
 select document into v_doc from canon.quest_draft_revisions
 where draft_id=p_draft and revision=p_revision;
 if v_doc is null or not exists(select 1 from canon.quest_drafts where id=p_draft and status='draft') or
    not exists(select 1 from jsonb_array_elements(coalesce(v_doc->'visualBriefs','[]'::jsonb)) b
      where b->>'id'=p_brief) then raise exception 'Unknown draft/revision/brief'; end if;
 select * into v_found from canon.quest_visual_jobs where actor_id=p_actor and request_key=p_request;
 if found then
   if v_found.draft_id<>p_draft or v_found.revision<>p_revision or v_found.brief_id<>p_brief or
      v_found.provider<>p_provider or v_found.model<>p_model then
     raise exception 'Idempotency key reused for different job'; end if;
   return jsonb_build_object('id',v_found.id,'status',v_found.status,'created',false);
 end if;
 -- Capped per actor, per rolling 24h; final authorization for larger budgets is separately configurable.
 if (select count(*) from canon.quest_visual_jobs where actor_id=p_actor and
     created_at>now()-interval '24 hours')>=20 then raise exception 'Daily job cap reached'; end if;
 select coalesce(sum(greatest(max_cost_usd,coalesce(actual_cost_usd,0))),0) into v_daily
 from canon.quest_visual_jobs where actor_id=p_actor and
   created_at>now()-interval '24 hours' and status<>'failed';
 if v_daily+p_max_cost_usd>5 then raise exception 'Daily generation budget reached'; end if;
 insert into canon.quest_visual_jobs(draft_id,revision,brief_id,actor_id,request_key,
    provider,model,max_cost_usd)
 values(p_draft,p_revision,p_brief,p_actor,p_request,p_provider,p_model,p_max_cost_usd)
 returning * into v_found;
 return jsonb_build_object('id',v_found.id,'status',v_found.status,'created',true);
end $$;

create function public.sideworld_quest_visual_inventory(
 p_actor uuid,p_draft uuid,p_revision integer
) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN'))
 then raise exception 'Admin required'; end if;
 if not exists(select 1 from canon.quest_draft_revisions where draft_id=p_draft and revision=p_revision)
 then raise exception 'Draft revision unavailable'; end if;
 return jsonb_build_object(
  'assets',coalesce((select jsonb_agg(jsonb_build_object(
    'id',a.id,'briefId',a.brief_id,'version',a.asset_version,'role',a.visual_role,
    'sha256',a.source_sha256,'mimeType',a.mime_type,'width',a.width,'height',a.height,
    'status',a.approval_status,'rightsNote',a.rights_note,'createdAt',a.created_at)
    order by a.created_at desc)
    from canon.quest_visual_assets a where a.draft_id=p_draft and a.revision=p_revision),'[]'::jsonb),
  'jobs',coalesce((select jsonb_agg(jsonb_build_object(
    'id',j.id,'briefId',j.brief_id,'status',j.status,'provider',j.provider,
    'model',j.model,'maxCostUsd',j.max_cost_usd,'actualCostUsd',j.actual_cost_usd,
    'createdAt',j.created_at) order by j.created_at desc)
    from canon.quest_visual_jobs j where j.draft_id=p_draft and j.revision=p_revision),'[]'::jsonb),
  'releases',coalesce((select jsonb_agg(jsonb_build_object(
    'id',r.id,'visibility',r.visibility,'revision',r.source_revision) order by r.created_at desc)
    from canon.quest_releases r where r.source_draft_id=p_draft and
      r.source_revision=p_revision and r.visibility='private_qa'),'[]'::jsonb),
  'bindings',coalesce((select jsonb_agg(jsonb_build_object(
    'releaseId',b.release_id,'assetId',b.asset_id,'sceneId',b.scene_id,'slot',b.slot))
    from canon.quest_visual_bindings b join canon.quest_releases r on r.id=b.release_id
    where r.source_draft_id=p_draft and r.source_revision=p_revision),'[]'::jsonb)
 );
end $$;

create function public.sideworld_quest_visual_review(
 p_actor uuid,p_asset uuid,p_expected_sha256 text,p_decision text
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN'))
 then raise exception 'Admin required'; end if;
 if p_decision not in ('approved','rejected') or p_expected_sha256 !~ '^[a-f0-9]{64}$'
 then raise exception 'Invalid review decision'; end if;
 update canon.quest_visual_assets set approval_status=p_decision,
   approved_by=case when p_decision='approved' then p_actor else null end,
   approved_at=case when p_decision='approved' then now() else null end
 where id=p_asset and source_sha256=p_expected_sha256 and approval_status='candidate'
   and exists(select 1 from storage.objects obj where obj.bucket_id=storage_bucket and obj.name=storage_path)
 returning id into v_id;
 return v_id is not null;
end $$;

create function public.sideworld_quest_visual_bind(
 p_actor uuid,p_release uuid,p_scene text,p_slot text,p_asset uuid
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_release canon.quest_releases;v_asset canon.quest_visual_assets;v_scene text;
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN'))
 then raise exception 'Admin required'; end if;
 select * into v_release from canon.quest_releases where id=p_release;
 select * into v_asset from canon.quest_visual_assets where id=p_asset and approval_status='approved';
 if v_release.id is null or v_asset.id is null or
   v_release.source_draft_id<>v_asset.draft_id or v_release.source_revision<>v_asset.revision or
   v_release.published_at is not null or p_slot not in ('cover','scene','evidence','notebook','finale') or
   p_scene is null or length(p_scene)>128 then raise exception 'Invalid immutable release binding'; end if;
 if p_scene<>'' and not exists(
   select 1 from jsonb_array_elements(v_release.document->'scenes') s where s->>'id'=p_scene)
 then raise exception 'Unrecognized scene'; end if;
 if p_scene='' and p_slot not in ('cover','finale') then raise exception 'Scene binding required'; end if;
 insert into canon.quest_visual_bindings(release_id,scene_id,slot,asset_id,created_by)
 values(p_release,p_scene,p_slot,p_asset,p_actor)
 on conflict do nothing;
 return exists(select 1 from canon.quest_visual_bindings where release_id=p_release
  and scene_id=p_scene and slot=p_slot and asset_id=p_asset);
end $$;

-- Only the Studio server may call completion, and ONLY AFTER byte-level Storage
-- upload/readback SHA-256 verification. This RPC checks metadata and ownership.
create function public.sideworld_quest_visual_complete(
 p_actor uuid,p_job uuid,p_sha256 text,p_mime text,p_width integer,p_height integer,
 p_role text,p_kind text,p_rights text,p_source_ref text,p_provenance jsonb,
 p_cost_usd numeric
) returns uuid language plpgsql security definer set search_path='' as $$
declare j canon.quest_visual_jobs; v_path text; v_asset uuid; v_version integer; v_ext text;
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN'))
 then raise exception 'Admin required'; end if;
 select * into j from canon.quest_visual_jobs where id=p_job and actor_id=p_actor and status='reserved' for update;
 if j.id is null then raise exception 'No reserved visual generation job'; end if;
 if p_sha256 !~ '^[a-f0-9]{64}
-- is implemented in Studio. NEVER flip the write flag
-- based only on the existence of these tables/RPCs.
revoke all on function public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_inventory(uuid,uuid,integer)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_review(uuid,uuid,text,text)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_bind(uuid,uuid,text,text,uuid)
 from public,anon,authenticated;
grant execute on function public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)
 to service_role;
grant execute on function public.sideworld_quest_visual_inventory(uuid,uuid,integer)
 to service_role;
grant execute on function public.sideworld_quest_visual_review(uuid,uuid,text,text)
 to service_role;
grant execute on function public.sideworld_quest_visual_bind(uuid,uuid,text,text,uuid)
 to service_role;
revoke all on function public.sideworld_quest_visual_complete(uuid,uuid,text,text,integer,integer,text,text,text,text,jsonb,numeric)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_fail(uuid,uuid,text)
 from public,anon,authenticated;
grant execute on function public.sideworld_quest_visual_complete(uuid,uuid,text,text,integer,integer,text,text,text,text,jsonb,numeric)
 to service_role;
grant execute on function public.sideworld_quest_visual_fail(uuid,uuid,text)
 to service_role;
revoke all on function public.sideworld_quest_visual_private_asset(uuid,uuid)
 from public,anon,authenticated;
grant execute on function public.sideworld_quest_visual_private_asset(uuid,uuid)
 to service_role;

comment on table canon.quest_visual_assets is
 'Quest-scoped approved/candidate artwork metadata. Immutable source SHA and private storage. No public image URLs.';
comment on table canon.quest_visual_jobs is
 'Single-request visual production budget reservations; no implicit AI calls. Requires server verified completion.';
 or p_mime not in ('image/png','image/jpeg','image/webp') or
    p_width not between 128 and 4096 or p_height not between 128 and 4096 or
    p_role not in ('cover','scene_backdrop','sketchbook','atlas','puzzle_evidence',
      'notebook_artifact','finale_art','historical_source','location_photo') or
    p_kind not in ('ai_illustration','manual_illustration','historical_source','real_photo') or
    (j.provider='openai' and p_kind<>'ai_illustration') or
    (j.provider='manual' and p_kind='ai_illustration') or
    (p_kind='ai_illustration' and p_role in ('historical_source','location_photo')) or
    (p_role='historical_source' and p_kind<>'historical_source') or
    (p_role='location_photo' and p_kind<>'real_photo') or
    length(btrim(p_rights)) not between 20 and 1000 or
    jsonb_typeof(p_provenance)<>'object' or pg_column_size(p_provenance)>16000 or
    (p_cost_usd is not null and (p_cost_usd<0 or p_cost_usd>10)) then raise exception 'Invalid asset metadata'; end if;
 v_ext=case p_mime when 'image/png' then '.png' when 'image/jpeg' then '.jpg' else '.webp' end;
 v_path=j.draft_id::text||'/r'||j.revision::text||'/'||p_sha256||v_ext;
 if not exists(select 1 from storage.objects where bucket_id='sideworld-quest-media' and name=v_path)
 then raise exception 'Verified private object not present'; end if;
 perform pg_advisory_xact_lock(hashtextextended(j.draft_id::text||':'||j.revision::text||':'||j.brief_id,8));
 select coalesce(max(asset_version),0)+1 into v_version from canon.quest_visual_assets
 where draft_id=j.draft_id and revision=j.revision and brief_id=j.brief_id;
 insert into canon.quest_visual_assets(draft_id,revision,brief_id,job_id,asset_version,
   visual_role,source_kind,storage_path,source_sha256,mime_type,width,height,
   source_ref,provenance,prompt_version,rights_note)
 values(j.draft_id,j.revision,j.brief_id,j.id,v_version,p_role,p_kind,
   v_path,p_sha256,p_mime,p_width,p_height,p_source_ref,p_provenance,
   nullif(p_provenance->>'promptVersion',''),p_rights)
 returning id into v_asset;
 update canon.quest_visual_jobs set status='completed',
   actual_cost_usd=p_cost_usd,usage=coalesce(p_provenance->'usage','{}'::jsonb),
   finished_at=now() where id=j.id;
 return v_asset;
end $$;

create function public.sideworld_quest_visual_fail(
 p_actor uuid,p_job uuid,p_error_code text
) returns boolean language plpgsql security definer set search_path='' as $$
declare v_id uuid;
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN'))
 then raise exception 'Admin required'; end if;
 if p_error_code is null or p_error_code !~ '^[A-Z0-9_]{3,64}
-- and durable job completion are implemented in Studio. NEVER flip the write flag
-- based only on the existence of these tables/RPCs.
revoke all on function public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_inventory(uuid,uuid,integer)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_review(uuid,uuid,text,text)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_bind(uuid,uuid,text,text,uuid)
 from public,anon,authenticated;
grant execute on function public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)
 to service_role;
grant execute on function public.sideworld_quest_visual_inventory(uuid,uuid,integer)
 to service_role;
grant execute on function public.sideworld_quest_visual_review(uuid,uuid,text,text)
 to service_role;
grant execute on function public.sideworld_quest_visual_bind(uuid,uuid,text,text,uuid)
 to service_role;

comment on table canon.quest_visual_assets is
 'Quest-scoped approved/candidate artwork metadata. Immutable source SHA and private storage. No public image URLs.';
comment on table canon.quest_visual_jobs is
 'Single-request visual production budget reservations; no implicit AI calls. Requires server verified completion.';

 then raise exception 'Invalid error code'; end if;
 update canon.quest_visual_jobs set status='failed',error_code=p_error_code,
   finished_at=now()
 where id=p_job and actor_id=p_actor and status='reserved' returning id into v_id;
 return v_id is not null;
end $$;

-- Admin-only lookup for server-side image preview bytes. No storage path is returned to browsers.
create function public.sideworld_quest_visual_private_asset(p_actor uuid,p_asset uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare a canon.quest_visual_assets;
begin
 if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN'))
 then raise exception 'Admin required'; end if;
 select * into a from canon.quest_visual_assets where id=p_asset;
 if a.id is null then return null; end if;
 return jsonb_build_object('id',a.id,'draftId',a.draft_id,'revision',a.revision,
  'storagePath',a.storage_path,'sha256',a.source_sha256,'mimeType',a.mime_type,
  'approval',a.approval_status);
end $$;

-- Guarded write APIs are intentionally incomplete until Storage byte verification
-- and durable job completion are implemented in Studio. NEVER flip the write flag
-- based only on the existence of these tables/RPCs.
revoke all on function public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_inventory(uuid,uuid,integer)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_review(uuid,uuid,text,text)
 from public,anon,authenticated;
revoke all on function public.sideworld_quest_visual_bind(uuid,uuid,text,text,uuid)
 from public,anon,authenticated;
grant execute on function public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)
 to service_role;
grant execute on function public.sideworld_quest_visual_inventory(uuid,uuid,integer)
 to service_role;
grant execute on function public.sideworld_quest_visual_review(uuid,uuid,text,text)
 to service_role;
grant execute on function public.sideworld_quest_visual_bind(uuid,uuid,text,text,uuid)
 to service_role;

comment on table canon.quest_visual_assets is
 'Quest-scoped approved/candidate artwork metadata. Immutable source SHA and private storage. No public image URLs.';
comment on table canon.quest_visual_jobs is
 'Single-request visual production budget reservations; no implicit AI calls. Requires server verified completion.';
