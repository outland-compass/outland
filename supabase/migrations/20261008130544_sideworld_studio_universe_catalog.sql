-- Studio catalog is a read-only projection of the single canonical universe.universes table.
-- Deploy to staging first. No universe duplicates, role changes or data mutation.
begin;
create or replace function public.sideworld_studio_list_universes()
returns jsonb language sql stable security definer
set search_path = pg_catalog, public
as $$
  select coalesce(jsonb_agg(
    jsonb_build_object('id', u.id, 'slug', u.slug, 'name', u.name, 'status', u.status)
    order by u.name, u.id
  ), '[]'::jsonb)
  from universe.universes u;
$$;
revoke all on function public.sideworld_studio_list_universes() from public, anon, authenticated;
grant execute on function public.sideworld_studio_list_universes() to service_role;
commit;
-- Rollback: drop function if exists public.sideworld_studio_list_universes();
