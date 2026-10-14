-- Run only on a disposable/local DB, or separately approved staging,
-- AFTER applying the reviewed migration there. READ-ONLY catalog assertions.
-- This is NOT proof of concurrency, live auth, publication, or SQL restore.
do $$
begin
  if not exists (select 1 from pg_namespace where nspname='player') then
    raise exception 'Missing player schema';
  end if;
  if (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace
      where (n.nspname='player' and c.relname in ('qa_access','quest_runs','run_receipts'))
         or (n.nspname='canon' and c.relname='quest_releases')) <> 4 then
    raise exception 'Incorrect Sideworld Player table inventory';
  end if;
  if exists(select 1 from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where ((n.nspname='player' and c.relname in ('qa_access','quest_runs','run_receipts'))
       or (n.nspname='canon' and c.relname='quest_releases')) and not c.relrowsecurity) then
    raise exception 'Player tables require RLS';
  end if;
  if exists(select 1 from pg_policies where
      (schemaname='player' and tablename in ('qa_access','quest_runs','run_receipts'))
       or (schemaname='canon' and tablename='quest_releases')) then
    raise exception 'Player initial tables must have no client RLS policies';
  end if;
  if has_table_privilege('anon','canon.quest_releases','SELECT')
    or has_table_privilege('authenticated','canon.quest_releases','SELECT')
    or has_table_privilege('service_role','canon.quest_releases','SELECT')
    or has_table_privilege('anon','player.quest_runs','SELECT')
    or has_table_privilege('authenticated','player.quest_runs','SELECT')
    or has_table_privilege('service_role','player.quest_runs','SELECT') then
    raise exception 'Player private tables exposed to API roles';
  end if;
  if has_function_privilege('anon','public.sideworld_player_release_get_v1(uuid,uuid)','EXECUTE')
    or has_function_privilege('authenticated','public.sideworld_player_release_get_v1(uuid,uuid)','EXECUTE')
    or has_function_privilege('anon','public.sideworld_player_run_apply_v1(uuid,uuid,uuid,text,integer,jsonb)','EXECUTE')
    or has_function_privilege('authenticated','public.sideworld_player_run_apply_v1(uuid,uuid,uuid,text,integer,jsonb)','EXECUTE') then
    raise exception 'Player private RPC exposed to client roles';
  end if;
  if has_function_privilege('anon','public.sideworld_player_run_receipt_get_v1(uuid,uuid,uuid)','EXECUTE')
    or has_function_privilege('authenticated','public.sideworld_player_run_receipt_get_v1(uuid,uuid,uuid)','EXECUTE') then
    raise exception 'Receipt RPC incorrectly exposed';
  end if;
  if not has_function_privilege('service_role','public.sideworld_player_release_get_v1(uuid,uuid)','EXECUTE')
    or not has_function_privilege('service_role','public.sideworld_player_run_apply_v1(uuid,uuid,uuid,text,integer,jsonb)','EXECUTE')
    or not has_function_privilege('service_role','public.sideworld_player_run_receipt_get_v1(uuid,uuid,uuid)','EXECUTE') then
    raise exception 'Expected backend RPC grants missing';
  end if;
  -- Proposed management endpoints must never be callable through a browser role.
  if has_function_privilege('anon',
       'public.sideworld_player_qa_release_create_v1(uuid,uuid,integer,text)','EXECUTE')
     or has_function_privilege('authenticated',
       'public.sideworld_player_qa_release_create_v1(uuid,uuid,integer,text)','EXECUTE')
     or has_function_privilege('anon',
       'public.sideworld_player_qa_grant_v1(uuid,uuid,uuid,timestamptz)','EXECUTE')
     or has_function_privilege('authenticated',
       'public.sideworld_player_qa_grant_v1(uuid,uuid,uuid,timestamptz)','EXECUTE')
     or has_function_privilege('anon',
       'public.sideworld_player_qa_revoke_v1(uuid,uuid,uuid)','EXECUTE')
     or has_function_privilege('authenticated',
       'public.sideworld_player_qa_revoke_v1(uuid,uuid,uuid)','EXECUTE') then
    raise exception 'Studio QA management RPC exposed to client roles';
  end if;
  if not has_function_privilege('service_role',
       'public.sideworld_player_qa_release_create_v1(uuid,uuid,integer,text)','EXECUTE')
     or not has_function_privilege('service_role',
       'public.sideworld_player_qa_grant_v1(uuid,uuid,uuid,timestamptz)','EXECUTE')
     or not has_function_privilege('service_role',
       'public.sideworld_player_qa_revoke_v1(uuid,uuid,uuid)','EXECUTE') then
    raise exception 'Required backend Studio QA operator grants missing';
  end if;
  if has_function_privilege('service_role',
       'player.is_qa_operator_v1(uuid)','EXECUTE') then
    raise exception 'Internal QA role helper exposed to client backend role';
  end if;
end $$;
select 'Player V1 read-only schema/security assertions passed' as result;
