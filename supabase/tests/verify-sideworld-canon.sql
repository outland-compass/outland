-- verify-sideworld-canon.sql
begin;

do $verify$
declare
  required_tables text[] := array[
    'franchises','series','characters','character_relationships',
    'factions','lore_facts','canon_rules'
  ];
  t text;
begin
  foreach t in array required_tables loop
    if to_regclass('canon.' || t) is null then
      raise exception 'Missing canon table: %', t;
    end if;
  end loop;

  if (select count(*)
      from pg_class c
      join pg_namespace n on n.oid=c.relnamespace
      where n.nspname='canon'
        and c.relname = any(required_tables)
        and c.relrowsecurity) <> array_length(required_tables,1) then
    raise exception 'RLS is not enabled on every canon table';
  end if;

  if has_schema_privilege('anon','canon','USAGE')
     or has_schema_privilege('authenticated','canon','USAGE')
     or has_schema_privilege('service_role','canon','USAGE') then
    raise exception 'Canon authoring schema unexpectedly exposed to API roles';
  end if;

  if not exists (
    select 1
    from information_schema.table_constraints tc
    join information_schema.constraint_column_usage ccu
      on ccu.constraint_name=tc.constraint_name
     and ccu.constraint_schema=tc.constraint_schema
    where tc.table_schema='canon'
      and tc.table_name='franchises'
      and tc.constraint_type='FOREIGN KEY'
      and ccu.table_schema='universe'
      and ccu.table_name='universes'
  ) then
    raise exception 'canon.franchises is not linked to universe.universes';
  end if;
end
$verify$;

rollback;
