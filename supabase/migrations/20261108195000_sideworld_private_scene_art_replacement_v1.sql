-- SIDEWORLD — controlled replacement of already-bound PRIVATE scene artwork.
-- Additive migration; apply to staging and verify before requesting any production approval.
-- Never changes quest_releases.document, source_revision, content hash, answers or publication.
-- No data backfill. Existing bindings and uploaded immutable media are preserved.
--
-- Deployment order: (1) this migration, (2) Studio code with feature flag OFF,
-- (3) turn on SIDEWORLD_PRIVATE_ART_REPLACE_ENABLED for a private founder test.
-- Rollback: turn the feature flag OFF. Keep this audit table, RPC and old media for
-- forensics / rollback by a future controlled replacement; do not delete evidence.

create table canon.quest_visual_binding_replacements (
  id bigint generated always as identity primary key,
  release_id uuid not null references canon.quest_releases(id) on delete restrict,
  scene_id text not null check (length(scene_id) between 1 and 128),
  slot text not null check (slot = 'scene'),
  previous_asset_id uuid not null references canon.quest_visual_assets(id) on delete restrict,
  replacement_asset_id uuid not null references canon.quest_visual_assets(id) on delete restrict,
  replaced_by uuid not null references auth.users(id) on delete restrict,
  replaced_at timestamptz not null default now(),
  check (previous_asset_id <> replacement_asset_id)
);
create index quest_visual_binding_replacements_release_idx
  on canon.quest_visual_binding_replacements(release_id,replaced_at desc);

comment on table canon.quest_visual_binding_replacements is
  'Append-only audit of approved private scene-art swaps. Old source assets remain immutable and available for restoration. No quest answers or tokens.';

alter table canon.quest_visual_binding_replacements enable row level security;
revoke all on canon.quest_visual_binding_replacements
  from public,anon,authenticated,service_role;
revoke all on sequence canon.quest_visual_binding_replacements_id_seq
  from public,anon,authenticated,service_role;

create function canon.guard_quest_visual_binding_replacements_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  raise exception 'Private scene artwork replacement history is append-only';
end $$;
create trigger quest_visual_binding_replacements_immutable_v1
before update or delete on canon.quest_visual_binding_replacements
for each row execute function canon.guard_quest_visual_binding_replacements_v1();
revoke all on function canon.guard_quest_visual_binding_replacements_v1()
  from public,anon,authenticated,service_role;

-- Compare-and-swap prevents stale editor tabs from replacing another editor's choice.
-- Executable only by the service-role Studio backend after cookie+admin authorization.
-- The function independently checks the actor's owner/admin role and every FK/brief/slot.
create function public.sideworld_quest_visual_replace_private_v1(
  p_actor uuid,p_release uuid,p_scene text,p_slot text,
  p_expected_asset uuid,p_new_asset uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  v_release canon.quest_releases%rowtype;
  v_binding canon.quest_visual_bindings%rowtype;
  v_previous canon.quest_visual_assets%rowtype;
  v_next canon.quest_visual_assets%rowtype;
begin
  if p_actor is null or p_release is null or p_scene is null or p_slot is distinct from 'scene' or
     p_scene !~ '^[a-z0-9][a-z0-9._-]{0,127}$' or
     p_expected_asset is null or p_new_asset is null or
     p_expected_asset = p_new_asset
  then return jsonb_build_object('kind','invalid'); end if;

  if not exists (
    select 1 from shared.user_roles
    where user_id=p_actor and role::text in ('OWNER','ADMIN')
  ) then raise exception 'Admin required'; end if;

  select * into v_release from canon.quest_releases
    where id=p_release for update;
  if v_release.id is null or v_release.visibility not in ('private','private_qa') or
     v_release.published_at is not null
  then return jsonb_build_object('kind','unavailable'); end if;

  if not exists (
    select 1 from jsonb_array_elements(v_release.document->'scenes') s
    where s->>'id'=p_scene
  ) then return jsonb_build_object('kind','invalid'); end if;

  select * into v_binding from canon.quest_visual_bindings
    where release_id=p_release and scene_id=p_scene and slot='scene'
    for update;
  if v_binding.release_id is null then
    return jsonb_build_object('kind','missing'); end if;
  if v_binding.asset_id=p_new_asset then
    return jsonb_build_object('kind','already_current','assetId',p_new_asset); end if;
  if v_binding.asset_id<>p_expected_asset then
    return jsonb_build_object('kind','conflict'); end if;

  select * into v_previous from canon.quest_visual_assets
    where id=p_expected_asset;
  select * into v_next from canon.quest_visual_assets
    where id=p_new_asset;
  if v_previous.id is null or v_next.id is null or
     v_previous.draft_id<>v_release.source_draft_id or
     v_previous.revision<>v_release.source_revision or
     v_next.draft_id<>v_release.source_draft_id or
     v_next.revision<>v_release.source_revision or
     v_next.brief_id<>v_previous.brief_id or
     v_next.visual_role<>v_previous.visual_role or
     v_next.visual_role not in ('scene_backdrop','sketchbook','atlas','location_photo') or
     v_next.approval_status<>'approved' or
     v_next.approved_by is null or v_next.approved_at is null or
     v_next.storage_bucket<>'sideworld-quest-media' or
     v_next.mime_type<>'image/webp' or
     (v_next.visual_role='location_photo' and v_next.source_kind<>'real_photo') or
     (v_next.visual_role<>'location_photo' and v_next.source_kind not in ('ai_illustration','manual_illustration')) or
     v_next.storage_path<>(v_next.draft_id::text||'/r'||v_next.revision::text||'/'||v_next.source_sha256||'.webp') or
     not exists (
       select 1 from storage.objects o
       where o.bucket_id=v_next.storage_bucket and o.name=v_next.storage_path
     )
  then return jsonb_build_object('kind','incompatible'); end if;

  update canon.quest_visual_bindings
    set asset_id=p_new_asset
    where release_id=p_release and scene_id=p_scene and slot='scene'
      and asset_id=p_expected_asset;
  if not found then return jsonb_build_object('kind','conflict'); end if;

  insert into canon.quest_visual_binding_replacements(
    release_id,scene_id,slot,previous_asset_id,replacement_asset_id,replaced_by
  ) values(p_release,p_scene,'scene',p_expected_asset,p_new_asset,p_actor);
  return jsonb_build_object('kind','replaced','assetId',p_new_asset,
    'previousAssetId',p_expected_asset,'sceneId',p_scene);
end $$;

revoke all on function public.sideworld_quest_visual_replace_private_v1(uuid,uuid,text,text,uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.sideworld_quest_visual_replace_private_v1(uuid,uuid,text,text,uuid,uuid)
  to service_role;
