-- SIDEWORLD multi-evidence review V1 — additive scoped approval metadata.
-- Canonical database: OUTLAND; consumed by SIDEWORLD Studio/Player.
-- STAGING FIRST. DO NOT APPLY IN PRODUCTION WITHOUT A SEPARATE EXPLICIT
-- FOUNDER AUTHORISATION, VERIFIED BACKUP AND RESTORE READINESS.
--
-- Invariant: legacy/single visual briefs retain at most one approved primary.
-- Approved evidence-piece images may share a brief, but only after individually
-- authorising the exact original in the existing sideworld_quest_visual_review RPC.
-- No changes to quest documents, universe data, Storage or existing statuses.
--
-- Safety: existing records default to 'single'. Marking as evidence_piece is
-- OWNER/ADMIN + service-role only, requires SHA, a candidate record and a
-- canonical visual brief. Unrelated historical photos and portraits cannot opt in.

alter table canon.quest_visual_assets
  add column approval_scope text not null default 'single';

alter table canon.quest_visual_assets
  add constraint quest_visual_approval_scope_check
  check (approval_scope in ('single','evidence_piece'));

alter table canon.quest_visual_assets
  add constraint quest_visual_evidence_piece_provenance
  check (approval_scope='single' or (
    source_kind='manual_illustration'
    and visual_role in ('sketchbook','atlas','puzzle_evidence','scene_backdrop')
    and source_ref is not null
    and length(btrim(source_ref)) between 8 and 200
  ));

-- Create a replacement index before removing the legacy broad one. Existing
-- approved images remain 'single', so their uniqueness does not change.
create unique index quest_visual_one_approved_single_per_brief
on canon.quest_visual_assets(draft_id,revision,brief_id)
where approval_status='approved' and approval_scope='single';

drop index canon.quest_visual_one_approved_per_brief;

create function public.sideworld_quest_visual_mark_evidence_piece(
  p_actor uuid,
  p_asset uuid,
  p_expected_sha256 text
) returns boolean
language plpgsql
security definer
set search_path=''
as $function$
declare
  a canon.quest_visual_assets;
begin
  if p_actor is null or p_asset is null or
     p_expected_sha256 is null or p_expected_sha256 !~ '^[a-f0-9]{64}$'
  then return false; end if;

  if not exists (
    select 1 from shared.user_roles
    where user_id=p_actor and role::text in ('OWNER','ADMIN')
  ) then raise exception 'Admin required'; end if;

  select * into a from canon.quest_visual_assets
  where id=p_asset for update;

  if a.id is null or a.approval_status<>'candidate'
     or a.source_sha256<>p_expected_sha256
     or a.source_kind<>'manual_illustration'
     or a.visual_role not in ('sketchbook','atlas','puzzle_evidence','scene_backdrop')
     or a.source_ref is null or length(btrim(a.source_ref)) not between 8 and 200
     or not exists (
       select 1 from storage.objects o
       where o.bucket_id=a.storage_bucket and o.name=a.storage_path
     )
     or not exists (
       select 1 from canon.quest_draft_revisions dr
       join canon.quest_drafts d on d.id=dr.draft_id
       where dr.draft_id=a.draft_id and dr.revision=a.revision
         and d.status='draft'
         and exists (
           select 1 from jsonb_array_elements(dr.document->'visualBriefs') brief
           where brief->>'id'=a.brief_id
         )
     )
  then return false; end if;

  if a.approval_scope='evidence_piece' then return true; end if;
  update canon.quest_visual_assets
  set approval_scope='evidence_piece' where id=a.id and approval_status='candidate';
  return found;
end;
$function$;

revoke all on function public.sideworld_quest_visual_mark_evidence_piece(uuid,uuid,text)
  from public,anon,authenticated;
grant execute on function public.sideworld_quest_visual_mark_evidence_piece(uuid,uuid,text)
  to service_role;

comment on column canon.quest_visual_assets.approval_scope is
  'single preserves one-approved-per-brief; evidence_piece requires individually reviewed manually sourced multi-image evidence. This is not a public rights grant.';

-- After applying to staging, run the checked preview query in
-- supabase/tests/verify-sideworld-multi-evidence-review.sql.
