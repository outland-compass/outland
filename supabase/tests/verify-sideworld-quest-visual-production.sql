-- Read-only SIDEWORLD Quest Visual Production schema/security assertions.
-- Run only after all SIDEWORLD Player and quest visual migrations have applied.
DO $$
declare v_count integer;
begin
 if not exists(select 1 from storage.buckets where id='sideworld-quest-media' and public=false)
 then raise exception 'quest media bucket must be private'; end if;
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='canon' and c.relname='quest_visual_assets' and c.relrowsecurity)
 then raise exception 'quest visual assets must have RLS enabled'; end if;
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='canon' and c.relname='quest_visual_jobs' and c.relrowsecurity)
 then raise exception 'quest visual jobs must have RLS enabled'; end if;
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where n.nspname='canon' and c.relname='quest_visual_bindings' and c.relrowsecurity)
 then raise exception 'quest visual bindings must have RLS enabled'; end if;
 if has_table_privilege('anon','canon.quest_visual_assets','SELECT') or
    has_table_privilege('authenticated','canon.quest_visual_assets','INSERT') or
    has_table_privilege('authenticated','canon.quest_visual_jobs','UPDATE') or
    has_table_privilege('anon','canon.quest_visual_bindings','SELECT')
 then raise exception 'client roles must not query private visual tables'; end if;
 if exists(select 1 from pg_policies where schemaname='storage' and tablename='objects'
     and (roles::text like '%anon%' or roles::text like '%authenticated%')
     and policyname like '%quest%media%')
 then raise exception 'quest private object access must not have browser policies'; end if;
 if exists(select 1 from pg_policies where schemaname='canon' and
     tablename in ('quest_visual_assets','quest_visual_jobs','quest_visual_bindings'))
 then raise exception 'browser-visible canon media policies are not allowed'; end if;
 if has_function_privilege('anon','public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)','EXECUTE') or
    has_function_privilege('authenticated','public.sideworld_quest_visual_review(uuid,uuid,text,text)','EXECUTE') or
    has_function_privilege('authenticated','public.sideworld_quest_visual_for_release(uuid,text,text)','EXECUTE')
 then raise exception 'visual administration/read APIs must be service-only'; end if;
 if not has_function_privilege('service_role','public.sideworld_quest_visual_complete(uuid,uuid,text,text,integer,integer,text,text,text,text,jsonb,numeric)','EXECUTE') or
    not has_function_privilege('service_role','public.sideworld_quest_visual_for_release(uuid,text,text)','EXECUTE')
 then raise exception 'required service-only visual RPC grants missing'; end if;
 select count(*) into v_count from canon.quest_visual_assets;
 if v_count<>0 then raise exception 'clean migration unexpectedly created media records'; end if;
 if (select count(*) from canon.quest_visual_bindings)<>0 then
   raise exception 'clean migration must not bind or publish quest content'; end if;
end $$;

select 'PASS: private asset, job and release-binding access is service-only with no data mutations' as result;
