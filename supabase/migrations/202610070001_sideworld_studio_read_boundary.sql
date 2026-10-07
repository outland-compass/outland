-- SIDEWORLD Studio V0-C — private read boundary
-- Candidate migration only. Do not execute against staging/production without explicit approval.
--
-- Purpose:
--   Expose one read-only RPC in public for the server-side Studio application while
--   keeping universe/geo/canon themselves outside the Data API exposure list.
--
-- Security model:
--   * SECURITY DEFINER function owned by the migration owner.
--   * No direct grants on private authoring schemas/tables.
--   * EXECUTE granted only to service_role.
--   * anon/authenticated/PUBLIC explicitly revoked.
--   * All private relations referenced with fully qualified names.
--   * search_path pinned to pg_catalog, public.

create or replace function public.sideworld_studio_read_model(p_universe_slug text)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
with selected_universe as (
  select u.id, u.slug, u.name, u.visibility, u.status, u.description
  from universe.universes u
  where u.slug = p_universe_slug
  limit 1
),
selected_franchises as (
  select f.*
  from canon.franchises f
  join selected_universe u on u.id = f.universe_id
),
selected_series as (
  select s.*
  from canon.series s
  join selected_franchises f on f.id = s.franchise_id
)
select jsonb_build_object(
  'universe',
    (
      select jsonb_build_object(
        'id', u.id,
        'slug', u.slug,
        'name', u.name,
        'visibility', u.visibility,
        'status', u.status,
        'description', u.description
      )
      from selected_universe u
    ),
  'franchises',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'universeId', f.universe_id,
          'slug', f.slug,
          'name', f.name,
          'description', f.description,
          'status', f.status,
          'canonVersion', f.canon_version
        )
        order by f.name, f.id
      )
      from selected_franchises f
    ), '[]'::jsonb),
  'series',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'franchiseId', s.franchise_id,
          'themeId', s.theme_id,
          'slug', s.slug,
          'name', s.name,
          'premise', s.premise,
          'status', s.status,
          'sortOrder', s.sort_order
        )
        order by s.sort_order, s.name, s.id
      )
      from selected_series s
    ), '[]'::jsonb),
  'characters',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', c.id,
          'franchiseId', c.franchise_id,
          'slug', c.slug,
          'name', c.name,
          'displayName', c.display_name,
          'role', c.role,
          'bio', c.bio,
          'canonStatus', c.canon_status
        )
        order by c.name, c.id
      )
      from canon.characters c
      join selected_franchises f on f.id = c.franchise_id
    ), '[]'::jsonb),
  'factions',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', x.id,
          'franchiseId', x.franchise_id,
          'slug', x.slug,
          'name', x.name,
          'factionType', x.faction_type,
          'description', x.description,
          'visibility', x.visibility,
          'canonStatus', x.canon_status
        )
        order by x.name, x.id
      )
      from canon.factions x
      join selected_franchises f on f.id = x.franchise_id
    ), '[]'::jsonb),
  'lore',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', l.id,
          'franchiseId', l.franchise_id,
          'seriesId', l.series_id,
          'factKey', l.fact_key,
          'statement', l.statement,
          'canonStatus', l.canon_status,
          'revealPhase', l.reveal_phase,
          'visibility', l.visibility
        )
        order by l.fact_key, l.id
      )
      from canon.lore_facts l
      join selected_franchises f on f.id = l.franchise_id
    ), '[]'::jsonb),
  'rules',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', r.id,
          'franchiseId', r.franchise_id,
          'seriesId', r.series_id,
          'characterId', r.character_id,
          'ruleType', r.rule_type,
          'ruleText', r.rule_text,
          'severity', r.severity,
          'status', r.status
        )
        order by
          case r.severity when 'error' then 1 when 'warning' then 2 else 3 end,
          r.rule_type,
          r.id
      )
      from canon.canon_rules r
      join selected_franchises f on f.id = r.franchise_id
    ), '[]'::jsonb),
  'cities',
    coalesce((
      select jsonb_agg(to_jsonb(city_row) order by city_row.name, city_row.id)
      from (
        select distinct
          c.id,
          c.country_code as "countryCode",
          c.slug,
          c.name,
          c.region,
          c.timezone,
          c.default_locale as "defaultLocale",
          c.status,
          c.verification_status as "verificationStatus"
        from universe.worlds w
        join selected_universe u on u.id = w.universe_id
        join universe.world_cities wc on wc.world_id = w.id
        join geo.cities c on c.id = wc.city_id
      ) city_row
    ), '[]'::jsonb)
);
$$;

revoke all on function public.sideworld_studio_read_model(text)
  from public, anon, authenticated, service_role;

grant execute on function public.sideworld_studio_read_model(text)
  to service_role;

comment on function public.sideworld_studio_read_model(text) is
  'SIDEWORLD Studio V0-C read-only server RPC. service_role only; private schemas remain outside Data API exposure.';
