-- verify-sideworld-geo.sql
begin;

do $verify$
declare
  required_tables text[] := array[
    'countries','cities','locations','location_facts','sources','fact_sources'
  ];
  t text;
begin
  foreach t in array required_tables loop
    if to_regclass('geo.' || t) is null then
      raise exception 'Missing geo table: %', t;
    end if;
  end loop;

  if (select count(*)
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='geo'
        and c.relname = any(required_tables)
        and c.relrowsecurity) <> array_length(required_tables,1) then
    raise exception 'RLS is not enabled on every geo table';
  end if;

  if has_schema_privilege('anon','geo','USAGE')
     or has_schema_privilege('authenticated','geo','USAGE')
     or has_schema_privilege('service_role','geo','USAGE') then
    raise exception 'Geo authoring schema unexpectedly exposed to API roles';
  end if;

  if not exists (
    select 1
    from information_schema.table_constraints tc
    join information_schema.constraint_column_usage ccu
      on ccu.constraint_name=tc.constraint_name
     and ccu.constraint_schema=tc.constraint_schema
    where tc.table_schema='geo'
      and tc.table_name='locations'
      and tc.constraint_type='FOREIGN KEY'
      and ccu.table_schema='geo'
      and ccu.table_name='cities'
  ) then
    raise exception 'geo.locations is not linked to geo.cities';
  end if;
end
$verify$;

rollback;
