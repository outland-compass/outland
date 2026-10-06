-- verify-sideworld-universe.sql
-- DRAFT verification for Migration 1 + 3.
begin;

do $verify$
declare
  required_tables text[] := array[
    'universes','worlds','themes','world_cities','world_outland_map'
  ];
  t text;
begin
  foreach t in array required_tables loop
    if to_regclass('universe.' || t) is null then
      raise exception 'Missing universe table: %', t;
    end if;
  end loop;

  if to_regprocedure('universe.set_updated_at()') is null then
    raise exception 'Existing universe.set_updated_at() compatibility helper was removed';
  end if;

  if not exists (
    select 1
    from information_schema.triggers
    where event_object_schema='passport'
      and event_object_table='journeys'
      and trigger_name='passport_journeys_set_updated_at'
      and action_statement ilike '%universe.set_updated_at%'
  ) then
    raise exception 'Passport journey updated_at trigger no longer references universe.set_updated_at()';
  end if;

  if to_regclass('shared.worlds') is null then
    raise exception 'Existing OUTLAND shared.worlds was removed';
  end if;

  if (select count(*)
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='universe'
        and c.relname = any(required_tables)
        and c.relrowsecurity) <> array_length(required_tables,1) then
    raise exception 'RLS is not enabled on every SIDEWORLD universe table';
  end if;

  if has_schema_privilege('anon','universe','USAGE')
     or has_schema_privilege('authenticated','universe','USAGE')
     or has_schema_privilege('service_role','universe','USAGE') then
    raise exception 'Universe authoring schema unexpectedly exposed to API roles';
  end if;
end
$verify$;

rollback;
