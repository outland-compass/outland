-- SIDEWORLD R17 in-place editorial save V1 (proposed, NOT yet deployed).
-- Only the exact private Novi Sad draft R17 is editable via this function.
-- No R18 creation. Existing releases and older revisions are unchanged.
-- Deployment requires explicit founder approval, verified backup/restore and CI.
--
-- Rollback: turn OFF SIDEWORLD_R17_IN_PLACE_SAVE_ENABLED in Studio first.
-- Revoke EXECUTE on the new RPC if needed; keep this audit table and records.
-- Do not revert the R17 document by running ad-hoc SQL.

create table if not exists canon.quest_draft_edit_history (
  id bigint generated always as identity primary key,
  draft_id uuid not null references canon.quest_drafts(id) on delete restrict,
  revision integer not null,
  previous_document jsonb not null,
  previous_diagnostics jsonb not null,
  edited_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint quest_draft_edit_history_revision_positive check (revision>0),
  constraint quest_draft_edit_history_document_check
    check (jsonb_typeof(previous_document)='object'
      and previous_document->>'contractVersion'='1'),
  constraint quest_draft_edit_history_diagnostics_check
    check (jsonb_typeof(previous_diagnostics)='array'),
  constraint quest_draft_edit_history_revision_fk
    foreign key (draft_id,revision)
    references canon.quest_draft_revisions(draft_id,revision) on delete restrict
);
create index if not exists quest_draft_edit_history_draft_revision_recent
  on canon.quest_draft_edit_history(draft_id,revision,id desc);
alter table canon.quest_draft_edit_history enable row level security;
revoke all on canon.quest_draft_edit_history from public,anon,authenticated,service_role;

create or replace function public.sideworld_quest_draft_save_current_r17_v1(
  p_id uuid,
  p_actor uuid,
  p_expected_revision integer,
  p_expected_document jsonb,
  p_document jsonb,
  p_diagnostics jsonb
) returns jsonb
language plpgsql security definer set search_path = ''
as $function$
declare
  d canon.quest_drafts;
  current_row canon.quest_draft_revisions;
  audit_id bigint;
begin
  -- Fail closed until the Studio's authenticated OWNER/ADMIN session has
  -- supplied a real actor identity. No direct public or browser access.
  if p_actor is null or not exists (
    select 1 from shared.user_roles
    where user_id=p_actor and role::text in ('OWNER','ADMIN')
  ) then
    return jsonb_build_object('kind','unavailable');
  end if;
  if p_id is distinct from 'd53c11cf-e5ea-4f36-a1b8-5301a20dfb1e'::uuid
     or p_expected_revision is distinct from 17 then
    return jsonb_build_object('kind','out_of_scope');
  end if;
  if p_expected_document is null or jsonb_typeof(p_expected_document)<>'object'
     or p_document is null or jsonb_typeof(p_document)<>'object'
     or p_document->>'contractVersion' is distinct from '1'
     or pg_column_size(p_document)>250000
     or p_diagnostics is null or jsonb_typeof(p_diagnostics)<>'array' then
    return jsonb_build_object('kind','invalid');
  end if;
  -- Serialize edits to this draft and its active revision. The full JSONB
  -- compare prevents lost updates even though R17 does not increment.
  select * into d from canon.quest_drafts where id=p_id for update;
  if not found or d.status<>'draft' or d.revision<>17 then
    return jsonb_build_object('kind','conflict');
  end if;
  select * into current_row from canon.quest_draft_revisions
    where draft_id=d.id and revision=17 for update;
  if not found or current_row.document is distinct from p_expected_document then
    return jsonb_build_object('kind','conflict');
  end if;
  -- Never rewrite a released or media-linked revision. R17 currently has
  -- zero direct releases, assets and jobs, confirmed read-only preflight.
  if exists(select 1 from canon.quest_releases where source_draft_id=d.id and source_revision=17)
    or exists(select 1 from canon.quest_visual_assets where draft_id=d.id and revision=17)
    or exists(select 1 from canon.quest_visual_jobs where draft_id=d.id and revision=17) then
    return jsonb_build_object('kind','dependencies');
  end if;
  if p_document->'scope'->>'universeId' is distinct from d.universe_id::text
     or p_document->'scope'->>'franchiseId' is distinct from d.franchise_id::text
     or p_document->'scope'->>'seriesId' is distinct from d.series_id::text
     or p_document->'scope'->>'cityId' is distinct from d.city_id::text then
    return jsonb_build_object('kind','scope_mismatch');
  end if;
  if current_row.document=p_document and current_row.diagnostics=p_diagnostics then
    return jsonb_build_object('kind','unchanged','revision',17);
  end if;
  -- Atomic lossless checkpoint BEFORE changing the active document.
  insert into canon.quest_draft_edit_history(
    draft_id,revision,previous_document,previous_diagnostics,edited_by
  ) values (
    d.id,17,current_row.document,current_row.diagnostics,p_actor
  ) returning id into audit_id;
  update canon.quest_draft_revisions
    set document=p_document, diagnostics=p_diagnostics
    where draft_id=d.id and revision=17;
  update canon.quest_drafts set updated_at=now() where id=d.id;
  return jsonb_build_object('kind','saved','revision',17,'checkpointId',audit_id);
end;
$function$;

revoke all on function public.sideworld_quest_draft_save_current_r17_v1(
  uuid,uuid,integer,jsonb,jsonb,jsonb) from public,anon,authenticated;
grant execute on function public.sideworld_quest_draft_save_current_r17_v1(
  uuid,uuid,integer,jsonb,jsonb,jsonb) to service_role;

comment on function public.sideworld_quest_draft_save_current_r17_v1(
  uuid,uuid,integer,jsonb,jsonb,jsonb) is
  'Founder-only, CAS-guarded same-revision R17 editorial save; auditable and never a release.';
