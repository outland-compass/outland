-- SIDEWORLD Studio V0-F City Knowledge verification.
begin;

set local role service_role;

select public.sideworld_studio_save_country('ZZ','Test Country','en');

select public.sideworld_studio_save_city(
  null,'ZZ','__city_kb_test__','City KB Test',null,'UTC','en',
  null,null,'draft','unverified'
);

select public.sideworld_studio_save_location(
  null,
  (select id from geo.cities where country_code='ZZ' and slug='__city_kb_test__'),
  'test-square',
  'Test Square',
  'poi',
  45.2500,
  19.8500,
  '1 Test Street',
  true,
  'partially_verified'
);

select public.sideworld_studio_save_location_fact(
  null,
  (select id from geo.cities where country_code='ZZ' and slug='__city_kb_test__'),
  (select l.id
   from geo.locations l
   join geo.cities c on c.id=l.city_id
   where c.country_code='ZZ' and c.slug='__city_kb_test__' and l.slug='test-square'),
  'test-square-founded',
  'Test Square is a transactional verification fixture.',
  'history',
  'partially_verified',
  0.8
);

select public.sideworld_studio_save_source(
  null,
  'https://example.invalid/test-square',
  'Test Publisher',
  'City KB Test Source',
  'official',
  null,
  'A'
);

select public.sideworld_studio_save_fact_source(
  (select f.id
   from geo.location_facts f
   join geo.cities c on c.id=f.city_id
   where c.country_code='ZZ' and c.slug='__city_kb_test__' and f.fact_key='test-square-founded'),
  (select s.id
   from geo.sources s
   where s.title='City KB Test Source'
   order by s.created_at desc, s.id desc
   limit 1),
  'supports',
  'Transactional verification link.'
);

do $verify$
declare
  v_city_id uuid;
  payload jsonb;
begin
  select id into v_city_id
  from geo.cities
  where country_code='ZZ' and slug='__city_kb_test__';

  select public.sideworld_studio_city_knowledge(v_city_id) into payload;

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
