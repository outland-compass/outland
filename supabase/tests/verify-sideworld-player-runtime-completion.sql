-- SIDEWORLD Player completion V2: read-only catalog/security assertions.
-- Run only where 20261014230000_sideworld_player_runtime_completion_v1 is applied.
do $$
begin
  if to_regprocedure('public.sideworld_player_run_apply_v2(uuid,uuid,uuid,text,integer,jsonb,boolean)') is null then
    raise exception 'Missing Player terminal-status V2 RPC';
  end if;
  if has_function_privilege('anon',
      'public.sideworld_player_run_apply_v2(uuid,uuid,uuid,text,integer,jsonb,boolean)','EXECUTE')
     or has_function_privilege('authenticated',
      'public.sideworld_player_run_apply_v2(uuid,uuid,uuid,text,integer,jsonb,boolean)','EXECUTE')
     or has_function_privilege('PUBLIC',
      'public.sideworld_player_run_apply_v2(uuid,uuid,uuid,text,integer,jsonb,boolean)','EXECUTE')
     or not has_function_privilege('service_role',
      'public.sideworld_player_run_apply_v2(uuid,uuid,uuid,text,integer,jsonb,boolean)','EXECUTE') then
    raise exception 'Player completion V2 RPC must be service-role-only';
  end if;
  if to_regprocedure('public.sideworld_player_run_apply_v1(uuid,uuid,uuid,text,integer,jsonb)') is null then
    raise exception 'Original Player V1 ABI missing';
  end if;
  if not exists (
    select 1 from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='sideworld_player_run_apply_v2'
      and p.prosecdef and p.proconfig @> array['search_path=']
  ) then
    raise exception 'Completion V2 must be SECURITY DEFINER with pinned empty search_path';
  end if;
  if not exists(select 1 from pg_constraint c
    where c.conrelid='player.quest_runs'::regclass and c.contype='c'
      and pg_get_constraintdef(c.oid) like '%completed%') then
    raise exception 'Expected quest_runs status check not present';
  end if;
end $$;
select 'Player completion V2 read-only catalog assertions passed' as result;
