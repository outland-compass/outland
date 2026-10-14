-- READ-ONLY assertions for the additive private QA operator audit migration.
-- Intended for clean/disposable migration replay. No application data access.
do $audit_contract$
begin
  if to_regclass('player.qa_operator_audit') is null then
    raise exception 'Missing durable QA operator audit';
  end if;
  if not exists(select 1 from information_schema.columns
       where table_schema='player' and table_name='qa_access'
       and column_name='revoked_by' and data_type='uuid') then
    raise exception 'Missing revocation operator provenance';
  end if;
  if not (select relrowsecurity from pg_class where oid='player.qa_operator_audit'::regclass) then
    raise exception 'QA operator audit requires RLS';
  end if;
  if exists(select 1 from pg_policies where schemaname='player'
       and tablename='qa_operator_audit') then
    raise exception 'Audit must have zero direct RLS policies';
  end if;
  if has_table_privilege('anon','player.qa_operator_audit','SELECT')
     or has_table_privilege('authenticated','player.qa_operator_audit','SELECT')
     or has_table_privilege('service_role','player.qa_operator_audit','SELECT')
     or has_table_privilege('anon','player.qa_operator_audit','INSERT')
     or has_table_privilege('authenticated','player.qa_operator_audit','INSERT')
     or has_table_privilege('service_role','player.qa_operator_audit','INSERT') then
    raise exception 'Private QA audit is exposed through Data API roles';
  end if;
  if has_function_privilege('anon','player.capture_qa_operator_audit_v1()','EXECUTE')
     or has_function_privilege('authenticated','player.capture_qa_operator_audit_v1()','EXECUTE')
     or has_function_privilege('service_role','player.capture_qa_operator_audit_v1()','EXECUTE') then
    raise exception 'Audit trigger must not be directly callable by client/backend roles';
  end if;
  if (select count(*) from pg_trigger where not tgisinternal
       and tgname in ('qa_operator_audit_immutable_v1','qa_release_audit_v1',
                      'qa_access_audit_v1'))<>3 then
    raise exception 'Missing append-only QA audit triggers';
  end if;
  if not has_function_privilege('service_role',
       'public.sideworld_player_qa_grant_v1(uuid,uuid,uuid,timestamptz)','EXECUTE')
     or not has_function_privilege('service_role',
       'public.sideworld_player_qa_revoke_v1(uuid,uuid,uuid)','EXECUTE')
     or has_function_privilege('anon',
       'public.sideworld_player_qa_revoke_v1(uuid,uuid,uuid)','EXECUTE')
     or has_function_privilege('authenticated',
       'public.sideworld_player_qa_revoke_v1(uuid,uuid,uuid)','EXECUTE') then
    raise exception 'QA RPC privilege boundary changed';
  end if;
end $audit_contract$;
select 'SIDEWORLD private QA durable audit is present and client-inaccessible' as result;
