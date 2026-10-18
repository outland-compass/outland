-- Read-only verification AFTER applying the reviewed manual media quota migration.
DO $$
declare v_def text;
begin
 select pg_get_functiondef(
   'public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)'::regprocedure
 ) into v_def;
 if position('provider=''manual''' in v_def)=0 or
    position('provider=''openai''' in v_def)=0 or
    position('>=120' in v_def)=0 or
    position('>=20' in v_def)=0 or
    position('v_daily+p_max_cost_usd>5' in v_def)=0 or
    position('Manual media import must reserve zero cost' in v_def)=0
 then raise exception 'Manual and AI quotas must remain distinct and bounded'; end if;
 if has_function_privilege('anon',
   'public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)','EXECUTE')
   or has_function_privilege('authenticated',
   'public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)','EXECUTE')
 then raise exception 'Browser roles may not reserve visual jobs'; end if;
 if not has_function_privilege('service_role',
   'public.sideworld_quest_visual_reserve(uuid,uuid,integer,text,uuid,text,text,numeric)','EXECUTE')
 then raise exception 'Service role must retain guarded visual reservation'; end if;
 if exists(select 1 from pg_policies where schemaname='canon' and tablename='quest_visual_jobs')
 then raise exception 'No browser-visible job policies allowed'; end if;
end $$;
select 'PASS: manual / AI quotas separated; guarded server-only API preserved' result;
