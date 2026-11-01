-- Read-only regression: multiple independently approved art assets per brief
-- are allowed, without weakening the existing review/audit guarantees.
do $assert$
begin
 if exists (
   select 1 from pg_indexes where schemaname='canon'
    and tablename='quest_visual_assets'
    and indexname='quest_visual_one_approved_per_brief'
 ) then raise exception 'Old single-art unique index still blocks evidence packs'; end if;
 if not exists (
   select 1 from pg_constraint
   where conrelid='canon.quest_visual_assets'::regclass
     and conname='quest_visual_approval_consistency'
 ) then raise exception 'Approval audit constraint missing'; end if;
 if not exists (
   select 1 from pg_constraint
   where conrelid='canon.quest_visual_assets'::regclass
     and conname='quest_visual_assets_source_sha256_check'
 ) then raise exception 'Original content hash invariant missing'; end if;
 if not exists (
   select 1 from pg_class
   where oid='canon.quest_visual_assets'::regclass and relrowsecurity
 ) then raise exception 'Visual asset RLS disabled'; end if;
 if has_table_privilege('anon','canon.quest_visual_assets','UPDATE') or
    has_table_privilege('authenticated','canon.quest_visual_assets','UPDATE')
 then raise exception 'Untrusted direct visual updates are allowed'; end if;
 if has_function_privilege('authenticated',
   'public.sideworld_quest_visual_review(uuid,uuid,text,text)','EXECUTE')
 then raise exception 'Untrusted visual review RPC permission'; end if;
end $assert$;
