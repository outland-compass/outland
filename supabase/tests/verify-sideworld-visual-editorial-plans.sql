-- Run AFTER the proposed additive visual editorial plan migration on a
-- disposable local Supabase instance. This script itself is read only.
do $verify$
begin
 if not exists(select 1 from pg_class where oid=
   'canon.quest_visual_editorial_plans'::regclass and relrowsecurity) then
    raise exception 'Visual editorial plan RLS must be enabled';
 end if;
 if exists(select 1 from pg_policies where schemaname='canon'
  and tablename='quest_visual_editorial_plans') then
    raise exception 'Private editorial plan table must not have client policies';
 end if;
 if has_table_privilege('anon','canon.quest_visual_editorial_plans','SELECT') or
    has_table_privilege('authenticated','canon.quest_visual_editorial_plans','SELECT') or
    has_table_privilege('authenticated','canon.quest_visual_editorial_plans','INSERT') or
    has_table_privilege('service_role','canon.quest_visual_editorial_plans','INSERT') then
   raise exception 'Editorial table must be reachable by service-only guarded RPC, never direct API';
 end if;
 if has_function_privilege('anon',
   'public.sideworld_quest_visual_editorial_get_v1(uuid,uuid,integer,uuid)','EXECUTE') or
    has_function_privilege('authenticated',
   'public.sideworld_quest_visual_editorial_get_v1(uuid,uuid,integer,uuid)','EXECUTE') or
    has_function_privilege('authenticated',
   'public.sideworld_quest_visual_editorial_save_v1(uuid,uuid,integer,uuid,text,integer,uuid,jsonb)','EXECUTE') or
    not has_function_privilege('service_role',
   'public.sideworld_quest_visual_editorial_save_v1(uuid,uuid,integer,uuid,text,integer,uuid,jsonb)','EXECUTE') then
   raise exception 'Editorial RPC privilege boundary is incorrect';
 end if;
 if (select count(*) from canon.quest_visual_editorial_plans)<>0 then
   raise exception 'Additive editorial plan migration must not create review rows';
 end if;
 if not exists(select 1 from pg_constraint where conrelid=
   'canon.quest_visual_editorial_plans'::regclass and contype='f'
   and pg_get_constraintdef(oid) like '%canon.quest_draft_revisions%') then
   raise exception 'Visual editorial plan must reference an immutable quest draft revision';
 end if;
 if not exists(select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
   where n.nspname='public' and p.proname='sideworld_quest_visual_editorial_save_v1'
   and p.prosecdef and p.proconfig @> array['search_path=']) then
   raise exception 'Editorial save RPC must be guarded with empty search_path';
 end if;
end $verify$;
select 'PASS: editor decisions are versioned, RLS protected and service-only' as result;
