begin;
do $$
begin
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='canon' and c.relname='quest_drafts' and c.relrowsecurity) then raise exception 'Draft RLS missing'; end if;
 if not exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='canon' and c.relname='quest_draft_revisions' and c.relrowsecurity) then raise exception 'Revision RLS missing'; end if;
 if has_table_privilege('anon','canon.quest_drafts','select') or has_table_privilege('authenticated','canon.quest_drafts','select') or has_table_privilege('service_role','canon.quest_drafts','insert') then raise exception 'Unexpected draft table grant'; end if;
 if has_function_privilege('anon','public.sideworld_quest_draft_begin(text,text,text,text,uuid,uuid,jsonb)','execute') or has_function_privilege('authenticated','public.sideworld_quest_draft_get(uuid,text,text,text,text)','execute') then raise exception 'Public draft RPC access'; end if;
 if not has_function_privilege('service_role','public.sideworld_quest_draft_save(uuid,uuid,integer,jsonb,jsonb,text,jsonb)','execute') then raise exception 'Missing service RPC grant'; end if;
 if public.sideworld_quest_draft_list('missing','missing','missing','missing')<>'[]'::jsonb then raise exception 'Cross-scope leak'; end if;
 if public.sideworld_quest_draft_get(gen_random_uuid(),'missing','missing','missing','missing') is not null then raise exception 'Cross-scope get leak'; end if;
 begin
  perform public.sideworld_quest_draft_begin('missing','missing','missing','missing',gen_random_uuid(),gen_random_uuid(),'{}');
  raise exception 'Expected authorization denial';
 exception when others then if sqlerrm<>'Admin required' then raise; end if;
 end;
end $$;
rollback;
