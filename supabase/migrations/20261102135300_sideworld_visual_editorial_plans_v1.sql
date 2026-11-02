-- SIDEWORLD Visual Editorial Plan V1 — ADDITIVE, REVIEW ONLY.
-- Canonical migration owner: OUTLAND. DO NOT APPLY TO PRODUCTION WITHOUT EXPLICIT
-- FOUNDER APPROVAL, VERIFIED BACKUP/ISOLATED RESTORE AND DRIFT RECONCILIATION.
-- Store decisions only. Never rewrite quest_draft_revisions, release documents,
-- media approvals, Player permissions, assets or scene bindings.
--
-- Readiness: production has the base quest and media tables, but the migration
-- ledger needs reconciliation against repo files (20261024/20261028 entries).
-- No universe tables are created or duplicated.

create table canon.quest_visual_editorial_plans (
  id uuid primary key default gen_random_uuid(),
  draft_id uuid not null,
  draft_revision integer not null check(draft_revision>0),
  release_id uuid references canon.quest_releases(id) on delete restrict,
  plan_version integer not null check(plan_version>0),
  scope_key text not null check(length(scope_key) between 1 and 250 and scope_key ~ '^[a-z0-9:-]+$'),
  decisions jsonb not null check(jsonb_typeof(decisions)='array' and
    jsonb_array_length(decisions) between 1 and 100 and pg_column_size(decisions)<=25000),
  reviewed_by uuid not null references auth.users(id) on delete restrict,
  request_key uuid not null,
  created_at timestamptz not null default now(),
  foreign key(draft_id,draft_revision)
    references canon.quest_draft_revisions(draft_id,revision) on delete restrict,
  unique(draft_id,draft_revision,plan_version),
  unique(reviewed_by,request_key)
);
create index quest_visual_editorial_latest on
  canon.quest_visual_editorial_plans(draft_id,draft_revision,plan_version desc);
alter table canon.quest_visual_editorial_plans enable row level security;
revoke all on canon.quest_visual_editorial_plans
  from public,anon,authenticated,service_role;

create function public.sideworld_quest_visual_editorial_get_v1(
 p_actor uuid,p_draft uuid,p_revision integer,p_release uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $function$
declare found_row canon.quest_visual_editorial_plans;
begin
 if not exists(select 1 from shared.user_roles
   where user_id=p_actor and role::text in ('OWNER','ADMIN')) then
   raise exception 'Editorial admin required';
 end if;
 select * into found_row from canon.quest_visual_editorial_plans
  where draft_id=p_draft and draft_revision=p_revision
    and release_id is not distinct from p_release
  order by plan_version desc limit 1;
 if not found then return null; end if;
 return jsonb_build_object(
   'version',found_row.plan_version,
   'releaseId',found_row.release_id,
   'reviewedAt',found_row.created_at,
   'reviewedBy',found_row.reviewed_by,
   'decisions',found_row.decisions
 );
end; $function$;

create function public.sideworld_quest_visual_editorial_save_v1(
 p_actor uuid,p_draft uuid,p_revision integer,p_release uuid,
 p_scope_key text,p_expected_version integer,p_request uuid,p_decisions jsonb)
returns jsonb language plpgsql security definer set search_path='' as $function$
declare
 v_draft canon.quest_drafts;
 v_document jsonb;
 v_prior canon.quest_visual_editorial_plans;
 v_saved canon.quest_visual_editorial_plans;
 v_last integer;
 v_target integer;
 v_item jsonb;
 v_scene text;
 v_moment text;
 v_action text;
 v_asset uuid;
 v_note text;
 v_count integer;
 v_seen text[] := array[]::text[];
begin
 if p_actor is null or not exists(select 1 from shared.user_roles
   where user_id=p_actor and role::text in ('OWNER','ADMIN')) then
   raise exception 'Editorial admin required';
 end if;
 if p_draft is null or p_request is null or p_revision is null or p_revision<=0
    or p_expected_version is null or p_expected_version<0
    or p_scope_key is null or length(p_scope_key) not between 1 and 250
    or p_scope_key !~ '^[a-z0-9:-]+$'
    or jsonb_typeof(p_decisions) is distinct from 'array'
    or pg_column_size(p_decisions)>25000 then
   raise exception 'Invalid editorial request';
 end if;
 v_count:=jsonb_array_length(p_decisions);
 if v_count<1 or v_count>100 then raise exception 'Invalid editorial count'; end if;
 select * into v_draft from canon.quest_drafts where id=p_draft for update;
 if not found or v_draft.status<>'draft' or v_draft.revision<>p_revision then
   raise exception 'Draft revision changed; reload before editor review';
 end if;
 select document into v_document from canon.quest_draft_revisions
    where draft_id=p_draft and revision=p_revision;
 if v_document is null or v_document->>'contractVersion' is distinct from '1' then
   raise exception 'Quest revision is unavailable';
 end if;
 if p_release is not null and not exists(
   select 1 from canon.quest_releases r where r.id=p_release
    and r.source_draft_id=p_draft and r.source_revision=p_revision
    and r.visibility in ('private','private_qa') and r.published_at is null) then
   raise exception 'Release is not a matching private revision';
 end if;
 -- This complete plan contains one entry per dialogue scene and, if
 -- present, exactly one virtual prologue; it cannot quietly omit moments.
 v_target:=jsonb_array_length(v_document->'scenes');
 if jsonb_typeof(v_document->'narrative'->'prologue')='array' then
   if jsonb_array_length(v_document->'narrative'->'prologue')>0 then
     v_target:=v_target+1;
   end if;
 end if;
 if v_count<>v_target then
   raise exception 'Every dialogue moment must be reviewed';
 end if;
 for v_item in select value from jsonb_array_elements(p_decisions) loop
   if jsonb_typeof(v_item)<>'object' or
     exists(select 1 from jsonb_object_keys(v_item) as k(key) where k.key not in
        ('momentId','sceneId','action','assetId','sha256','briefId','note')) then
     raise exception 'Unexpected review fields';
   end if;
   v_scene:=v_item->>'sceneId';
   v_moment:=v_item->>'momentId';
   v_action:=v_item->>'action';
   v_note:=v_item->>'note';
   if v_moment is null or length(v_moment)>150 or
     v_moment=any(v_seen) or v_action not in ('reuse','adjust','new') or
     v_note is null or length(v_note)>800 or v_note ~ '[<>]' then
     raise exception 'Invalid review moment, action or note';
   end if;
   v_seen:=array_append(v_seen,v_moment);
   if v_scene is null then
     if v_moment<>'prologue:dialogue' or
        jsonb_typeof(v_document->'narrative'->'prologue') is distinct from 'array' or
        jsonb_array_length(v_document->'narrative'->'prologue')=0 then
       raise exception 'Unexpected virtual dialogue moment';
     end if;
   elsif v_moment is distinct from v_scene||':dialogue' or not exists(
      select 1 from jsonb_array_elements(v_document->'scenes') s
       where s->>'id'=v_scene) then
     raise exception 'Unknown canonical dialogue scene';
   end if;
   if v_action='reuse' then
     if v_scene is null or
       coalesce(v_item->>'assetId','') !~
         '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$' or
       coalesce(v_item->>'sha256','') !~ '^[a-f0-9]{64}$' or
       coalesce(v_item->>'briefId','')='' then
       raise exception 'Exact approved artwork required';
     end if;
     v_asset:=(v_item->>'assetId')::uuid;
     if not exists(
       select 1 from canon.quest_visual_assets a
       where a.id=v_asset and a.draft_id=p_draft and a.revision=p_revision
         and a.approval_status='approved'
         and a.source_sha256=v_item->>'sha256'
         and a.brief_id=v_item->>'briefId'
         and (
           exists (select 1 from jsonb_array_elements(v_document->'visualBriefs') b
             where b->>'id'=a.brief_id and b->>'sceneId'=v_scene
                and b->>'kind' in ('atlas','sketchbook'))
           or (p_release is not null and exists(
             select 1 from canon.quest_visual_bindings bound
              where bound.release_id=p_release and bound.scene_id=v_scene
                and bound.slot='scene' and bound.asset_id=a.id))
         )) then
       raise exception 'Artwork is not an exact approved scene candidate';
     end if;
   else
     if v_item->'assetId' is distinct from 'null'::jsonb or
        v_item->'sha256' is distinct from 'null'::jsonb or
        v_item->'briefId' is distinct from 'null'::jsonb or
        length(btrim(v_note))<12 then
       raise exception 'Adjust/New requires a note, not an asset binding';
     end if;
   end if;
 end loop;
 select * into v_prior from canon.quest_visual_editorial_plans
  where reviewed_by=p_actor and request_key=p_request;
 if found then
   if v_prior.draft_id<>p_draft or v_prior.draft_revision<>p_revision or
     v_prior.release_id is distinct from p_release or
     v_prior.scope_key<>p_scope_key or v_prior.decisions<>p_decisions then
     raise exception 'Idempotency key already belongs to another plan';
   end if;
   return jsonb_build_object('version',v_prior.plan_version,
     'releaseId',v_prior.release_id,'reviewedAt',v_prior.created_at,
     'reviewedBy',v_prior.reviewed_by,'decisions',v_prior.decisions,
     'reused',true);
 end if;
 select coalesce(max(plan_version),0) into v_last
   from canon.quest_visual_editorial_plans
  where draft_id=p_draft and draft_revision=p_revision;
 if v_last<>p_expected_version then
   raise exception 'Editorial plan changed; reload before saving';
 end if;
 v_target:=v_last+1;
 insert into canon.quest_visual_editorial_plans
   (draft_id,draft_revision,release_id,plan_version,scope_key,
    decisions,reviewed_by,request_key)
 values (p_draft,p_revision,p_release,v_target,p_scope_key,
    p_decisions,p_actor,p_request)
 returning * into v_saved;
 return jsonb_build_object('version',v_saved.plan_version,
   'releaseId',v_saved.release_id,'reviewedAt',v_saved.created_at,
   'reviewedBy',v_saved.reviewed_by,'decisions',v_saved.decisions,
   'reused',false);
end; $function$;

revoke all on function
 public.sideworld_quest_visual_editorial_get_v1(uuid,uuid,integer,uuid),
 public.sideworld_quest_visual_editorial_save_v1(uuid,uuid,integer,uuid,text,integer,uuid,jsonb)
 from public,anon,authenticated;
grant execute on function
 public.sideworld_quest_visual_editorial_get_v1(uuid,uuid,integer,uuid),
 public.sideworld_quest_visual_editorial_save_v1(uuid,uuid,integer,uuid,text,integer,uuid,jsonb)
 to service_role;

comment on table canon.quest_visual_editorial_plans is
 'Immutable, founder-reviewed private dialogue shot selections, separate from approved assets, immutable Player releases and quest draft revisions. Studio server service-role RPC only; not a publication or billing approval.';
