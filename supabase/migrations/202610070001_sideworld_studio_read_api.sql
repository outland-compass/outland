-- SIDEWORLD Studio V0-B — read-only server facade
-- Keeps universe/geo/canon private while exposing a narrowly scoped RPC to service_role only.

create or replace function public.sideworld_studio_snapshot(
  p_universe_id uuid default null
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'universes', coalesce((
      select jsonb_agg(to_jsonb(u) order by u.name)
      from universe.universes u
      where p_universe_id is null or u.id = p_universe_id
    ), '[]'::jsonb),
    'worlds', coalesce((
      select jsonb_agg(to_jsonb(w) order by w.name)
      from universe.worlds w
      where p_universe_id is null or w.universe_id = p_universe_id
    ), '[]'::jsonb),
    'themes', coalesce((
      select jsonb_agg(to_jsonb(t) order by t.name)
      from universe.themes t
      where p_universe_id is null or t.universe_id is null or t.universe_id = p_universe_id
    ), '[]'::jsonb),
    'franchises', coalesce((
      select jsonb_agg(to_jsonb(f) order by f.name)
      from canon.franchises f
      where p_universe_id is null or f.universe_id = p_universe_id
    ), '[]'::jsonb),
    'series', coalesce((
      select jsonb_agg(to_jsonb(s) order by s.sort_order, s.name)
      from canon.series s
      join canon.franchises f on f.id = s.franchise_id
      where p_universe_id is null or f.universe_id = p_universe_id
    ), '[]'::jsonb),
    'characters', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.name)
      from canon.characters c
      join canon.franchises f on f.id = c.franchise_id
      where p_universe_id is null or f.universe_id = p_universe_id
    ), '[]'::jsonb),
    'relationships', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.created_at, r.id)
      from canon.character_relationships r
      join canon.franchises f on f.id = r.franchise_id
      where p_universe_id is null or f.universe_id = p_universe_id
    ), '[]'::jsonb),
    'factions', coalesce((
      select jsonb_agg(to_jsonb(fa) order by fa.name)
      from canon.factions fa
      join canon.franchises f on f.id = fa.franchise_id
      where p_universe_id is null or f.universe_id = p_universe_id
    ), '[]'::jsonb),
    'lore_facts', coalesce((
      select jsonb_agg(to_jsonb(l) order by l.fact_key)
      from canon.lore_facts l
      join canon.franchises f on f.id = l.franchise_id
      where p_universe_id is null or f.universe_id = p_universe_id
    ), '[]'::jsonb),
    'canon_rules', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.severity desc, r.created_at, r.id)
      from canon.canon_rules r
      join canon.franchises f on f.id = r.franchise_id
      where p_universe_id is null or f.universe_id = p_universe_id
    ), '[]'::jsonb),
    'cities', coalesce((
      select jsonb_agg(to_jsonb(c) order by c.name)
      from geo.cities c
      where p_universe_id is null
         or exists (
           select 1
           from universe.world_cities wc
           join universe.worlds w on w.id = wc.world_id
           where wc.city_id = c.id
             and w.universe_id = p_universe_id
         )
    ), '[]'::jsonb),
    'world_cities', coalesce((
      select jsonb_agg(to_jsonb(wc) order by wc.created_at, wc.world_id, wc.city_id)
      from universe.world_cities wc
      join universe.worlds w on w.id = wc.world_id
      where p_universe_id is null or w.universe_id = p_universe_id
    ), '[]'::jsonb)
  );
$$;

revoke all on function public.sideworld_studio_snapshot(uuid) from public;
revoke all on function public.sideworld_studio_snapshot(uuid) from anon, authenticated;
grant execute on function public.sideworld_studio_snapshot(uuid) to service_role;

comment on function public.sideworld_studio_snapshot(uuid) is
  'Read-only SIDEWORLD Studio V0-B facade. Private authoring schemas remain unexposed; callable by service_role only.';
