-- SIDEWORLD Private DNA Metadata Status RPC V1 — REVIEW PROPOSAL ONLY.
-- This file is deliberately NOT in supabase/migrations and MUST NOT be
-- executed against production without an approved migration, backup/restore,
-- security review, local CI and explicit founder production DB authorization.
--
-- When approved, use the Supabase CLI to generate a real migration filename
-- and copy reviewed SQL into that migration in outland-compass/outland.
--
-- This only reports the reserved namespace's presence/type/short safe
-- version. Existing full metadata, Character Bibles and sealed story records
-- MUST remain private and absent from RPC return values.

begin;

create or replace function public.sideworld_studio_dna_metadata_status_v1(
  p_universe_slug text
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public, pg_temp
as $function$
select jsonb_build_object(
  'schemaVersion', 1,
  'universeId', u.id,
  'universeSlug', u.slug,
  'rows', coalesce(
    (
      select jsonb_agg(
        jsonb_build_object(
          'franchiseId', f.id,
          'franchiseSlug', f.slug,
          'canonVersion', f.canon_version,
          'dnaNamespaceState',
            case
              when not (f.metadata ? 'experience_dna_v1') then 'absent'
              when jsonb_typeof(f.metadata -> 'experience_dna_v1') = 'object' then 'object'
              else 'malformed'
            end,
          'profileVersion',
            case when
              jsonb_typeof(f.metadata -> 'experience_dna_v1') = 'object'
              and jsonb_typeof(f.metadata #> '{experience_dna_v1,profileVersion}') = 'string'
              and (f.metadata #>> '{experience_dna_v1,profileVersion}')
                ~ '^[0-9]{1,3}(\.[0-9]{1,3}){0,2}$'
            then (f.metadata #>> '{experience_dna_v1,profileVersion}')
            else null
            end
        )
        order by f.slug, f.id
      )
      from canon.franchises f
      where f.universe_id = u.id
    ), '[]'::jsonb
  )
)
from universe.universes u
where u.slug = p_universe_slug
  and p_universe_slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$';
$function$;

-- Existing Studio boundaries use service-role-only SECURITY DEFINER RPCs.
-- Restrict EXECUTE in the same transaction as CREATE (no public interval).
revoke all on function public.sideworld_studio_dna_metadata_status_v1(text)
  from public, anon, authenticated, service_role;

grant execute on function public.sideworld_studio_dna_metadata_status_v1(text)
  to service_role;

commit;

-- Rollback (only after disabling the Studio flag and checking dependencies):
-- drop function if exists public.sideworld_studio_dna_metadata_status_v1(text);
