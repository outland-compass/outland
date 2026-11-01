-- SIDEWORLD: permanently allow more than one approved illustration per visual brief.
-- Canonical DB: OUTLAND. Existing Studio visual-review RPC remains the only
-- approved-by / approved-at writer. No change to identity, rights, RLS or Storage.
-- Existing SINGLE-art consumers remain independently fail-closed if ambiguous.
--
-- This is an explicitly requested product rule change (Golden Solo V3.1:
-- 18 separately reviewable evidence images across eight brief IDs).
-- REVIEW / BACKUP / RESTORE VERIFICATION BEFORE PRODUCTION APPLY.

do $guard$
declare v_def text;
begin
  select indexdef into v_def
    from pg_indexes
   where schemaname='canon'
     and tablename='quest_visual_assets'
     and indexname='quest_visual_one_approved_per_brief';
  if v_def is null then
    raise exception 'Expected legacy visual approval index missing; reconcile schema';
  end if;
  if v_def not like 'CREATE UNIQUE INDEX quest_visual_one_approved_per_brief ON canon.quest_visual_assets USING btree (draft_id, revision, brief_id) WHERE %' or
      v_def not like '%approval_status = ''approved''%' then
    raise exception 'Existing index definition has drifted: %',v_def;
  end if;
  if not exists (
    select 1 from pg_constraint
     where conrelid='canon.quest_visual_assets'::regclass
       and conname='quest_visual_approval_consistency'
  ) then
    raise exception 'Review audit consistency check is missing';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
     where n.nspname='public' and p.proname='sideworld_quest_visual_review'
       and pg_get_function_identity_arguments(p.oid)='p_actor uuid, p_asset uuid, p_expected_sha256 text, p_decision text'
  ) then
    raise exception 'Required guarded review function is missing';
  end if;
end $guard$;

drop index canon.quest_visual_one_approved_per_brief;

comment on table canon.quest_visual_assets is
 'Quest illustration metadata: multiple assets per brief can be individually approved by the guarded owner review RPC. Original SHA, private Storage, rights metadata and approval audit remain mandatory. No implicit public rights.';
