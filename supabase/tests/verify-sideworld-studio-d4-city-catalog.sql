-- SIDEWORLD Studio V0-D4 — City catalog must be independent of World mappings.
begin;

set local role service_role;

select public.sideworld_studio_save_universe(
  null,
  '__d4_city_catalog_test__',
  'D4 City Catalog Test',
  'private',
  'draft',
  'Transactional verification fixture.'
);

select public.sideworld_studio_save_country(
  'ZZ',
  'Test Country',
  'en'
);

select public.sideworld_studio_save_city(
  null,
  'ZZ',
  '__d4_unmapped_city__',
  'D4 Unmapped City',
  null,
  'UTC',
  'en',
  null,
  null,
  'draft',
  'unverified'
);

do $verify$
declare
  payload jsonb;
begin
  select public.sideworld_studio_read_model('__d4_city_catalog_test__') into payload;

  if jsonb_array_length(payload->'worlds') <> 0 then
    raise exception 'D4 fixture unexpectedly has Worlds: %', payload->'worlds';
  end if;

  if not exists (
    select 1
    from jsonb_array_elements(payload->'cities') city
    where city->>'slug'='__d4_unmapped_city__'
  ) then
    raise exception 'Unmapped City is missing from Studio city catalog: %', payload->'cities';
  end if;
end
$verify$;

reset role;
rollback;
