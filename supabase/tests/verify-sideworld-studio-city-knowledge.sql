-- SIDEWORLD Studio V0-F City Knowledge verification.
begin;

set local role service_role;

select public.sideworld_studio_save_country('ZZ','Test Country','en') as country_code;

select public.sideworld_studio_save_city(
  null,'ZZ','__city_kb_test__','City KB Test',null,'UTC','en',
  null,null,'draft','unverified'
) as city_id \gset

select public.sideworld_studio_save_location(
  null, :'city_id'::uuid, 'test-square', 'Test Square', 'poi',
  45.2500, 19.8500, '1 Test Street', true, 'partially_verified'
) as location_id \gset

select public.sideworld_studio_save_location_fact(
  null, :'city_id'::uuid, :'location_id'::uuid,
  'test-square-founded', 'Test Square is a transactional verification fixture.',
  'history', 'partially_verified', 0.8
) as fact_id \gset

select public.sideworld_studio_save_source(
  null, 'https://example.invalid/test-square', 'Test Publisher',
  'Test Source', 'official', null, 'A'
) as source_id \gset

select public.sideworld_studio_save_fact_source(
  :'fact_id'::uuid, :'source_id'::uuid, 'supports', 'Transactional verification link.'
);

do $verify$
declare
  payload jsonb;
begin
  select public.sideworld_studio_city_knowledge(:'city_id'::uuid) into payload;

  if payload->'city'->>'slug' <> '__city_kb_test__' then
    raise exception 'City Knowledge payload missing city: %', payload;
  end if;

  if jsonb_array_length(payload->'locations') <> 1 then
    raise exception 'Expected one location: %', payload->'locations';
  end if;

  if jsonb_array_length(payload->'facts') <> 1 then
    raise exception 'Expected one fact: %', payload->'facts';
  end if;

  if jsonb_array_length(payload->'sources') <> 1 then
    raise exception 'Expected one source: %', payload->'sources';
  end if;

  if jsonb_array_length(payload->'factSources') <> 1 then
    raise exception 'Expected one fact-source link: %', payload->'factSources';
  end if;
end
$verify$;

reset role;

do $security$
declare
  fn oid;
begin
  foreach fn in array array[
    to_regprocedure('public.sideworld_studio_city_knowledge(uuid)'),
    to_regprocedure('public.sideworld_studio_save_location(uuid,uuid,text,text,text,numeric,numeric,text,boolean,text)'),
    to_regprocedure('public.sideworld_studio_save_location_fact(uuid,uuid,uuid,text,text,text,text,numeric)'),
    to_regprocedure('public.sideworld_studio_save_source(uuid,text,text,text,text,timestamp with time zone,text)'),
    to_regprocedure('public.sideworld_studio_save_fact_source(uuid,uuid,text,text)')
  ]
  loop
    if fn is null then raise exception 'City Knowledge function missing'; end if;
    if has_function_privilege('anon',fn,'EXECUTE')
       or has_function_privilege('authenticated',fn,'EXECUTE') then
      raise exception 'Browser role can execute City Knowledge function %', fn;
    end if;
    if not has_function_privilege('service_role',fn,'EXECUTE') then
      raise exception 'service_role cannot execute City Knowledge function %', fn;
    end if;
  end loop;
end
$security$;

rollback;
