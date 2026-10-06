-- verify-sideworld-boundaries.sql
-- Protects OUTLAND operational identity from accidental SIDEWORLD repointing.
begin;

do $verify$
declare
  fk_count integer;
begin
  if to_regclass('shared.worlds') is null then
    raise exception 'shared.worlds missing';
  end if;
  if to_regclass('infrastructure.bases') is null then
    raise exception 'infrastructure.bases missing';
  end if;
  if to_regclass('shared.activities') is null then
    raise exception 'shared.activities missing';
  end if;

  if to_regnamespace('places') is not null
     and to_regclass('places.base') is not null then
    raise exception 'Competing places.base was created';
  end if;

  -- infrastructure.bases.world_id must still target shared.worlds.
  if not exists (
    select 1
    from pg_constraint c
    join pg_class src on src.oid=c.conrelid
    join pg_namespace srcn on srcn.oid=src.relnamespace
    join pg_class dst on dst.oid=c.confrelid
    join pg_namespace dstn on dstn.oid=dst.relnamespace
    where c.contype='f'
      and srcn.nspname='infrastructure'
      and src.relname='bases'
      and dstn.nspname='shared'
      and dst.relname='worlds'
  ) then
    raise exception 'infrastructure.bases no longer references shared.worlds';
  end if;

  -- Existing LAND World FKs must not be repointed to universe.worlds.
  if exists (
    select 1
    from pg_constraint c
    join pg_class src on src.oid=c.conrelid
    join pg_namespace srcn on srcn.oid=src.relnamespace
    join pg_class dst on dst.oid=c.confrelid
    join pg_namespace dstn on dstn.oid=dst.relnamespace
    where c.contype='f'
      and srcn.nspname='land'
      and dstn.nspname='universe'
      and dst.relname='worlds'
  ) then
    raise exception 'LAND FK was incorrectly repointed to universe.worlds';
  end if;

  -- The explicit bridge must target shared.worlds.
  if to_regclass('universe.world_outland_map') is not null and not exists (
    select 1
    from pg_constraint c
    join pg_class src on src.oid=c.conrelid
    join pg_namespace srcn on srcn.oid=src.relnamespace
    join pg_class dst on dst.oid=c.confrelid
    join pg_namespace dstn on dstn.oid=dst.relnamespace
    where c.contype='f'
      and srcn.nspname='universe'
      and src.relname='world_outland_map'
      and dstn.nspname='shared'
      and dst.relname='worlds'
  ) then
    raise exception 'universe.world_outland_map does not reference shared.worlds';
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema='shared' and table_name='activities' and column_name='entity_type'
  ) then
    raise exception 'shared.activities operational audit structure changed unexpectedly';
  end if;
end
$verify$;

rollback;
