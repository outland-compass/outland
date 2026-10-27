-- Read-only post-migration verification. Execute only after explicit approval
-- and migration application; do NOT run against current production beforehand.
do $$
declare
  v_table oid := to_regclass('geo.location_assessments');
begin
  if v_table is null then
    raise exception 'Location assessment migration has not been applied';
  end if;
  if not exists(
    select 1 from pg_class where oid=v_table and relrowsecurity=true
  ) then raise exception 'RLS must remain enabled'; end if;
  if has_table_privilege('authenticated',v_table,'SELECT') or
     has_table_privilege('authenticated',v_table,'INSERT') or
     has_table_privilege('anon',v_table,'SELECT') or
     has_table_privilege('service_role',v_table,'SELECT') or
     has_table_privilege('service_role',v_table,'INSERT')
    then raise exception 'Direct table privileges are forbidden'; end if;
  if has_function_privilege('anon',
      'public.sideworld_location_assessment_record_v1(uuid,uuid,uuid,integer,text,text,text,jsonb,numeric,jsonb,jsonb,boolean)',
      'EXECUTE') or
     has_function_privilege('authenticated',
      'public.sideworld_location_assessment_record_v1(uuid,uuid,uuid,integer,text,text,text,jsonb,numeric,jsonb,jsonb,boolean)',
      'EXECUTE') or
     has_function_privilege('anon',
      'public.sideworld_location_assessments_for_city_v1(uuid,uuid,text,text)',
      'EXECUTE') or
     has_function_privilege('authenticated',
      'public.sideworld_location_assessments_for_city_v1(uuid,uuid,text,text)',
      'EXECUTE')
    then raise exception 'Only server-side RPC callers are permitted'; end if;
  if not has_function_privilege('service_role',
      'public.sideworld_location_assessment_record_v1(uuid,uuid,uuid,integer,text,text,text,jsonb,numeric,jsonb,jsonb,boolean)',
      'EXECUTE') or
     not has_function_privilege('service_role',
      'public.sideworld_location_assessments_for_city_v1(uuid,uuid,text,text)',
      'EXECUTE')
    then raise exception 'Studio service role must have RPC execution'; end if;
  if not exists(
    select 1 from pg_constraint
    where conrelid=v_table and conname='geo_location_assessments_unique'
  ) then raise exception 'Immutable scoring fingerprint uniqueness missing'; end if;
  if exists(
    select 1 from pg_policies where schemaname='geo' and tablename='location_assessments'
  ) then raise exception 'Assessment table unexpectedly has a client policy'; end if;
  raise notice 'SIDEWORLD scoring V1: RLS, grants, RPC and uniqueness verified';
end
$$;
