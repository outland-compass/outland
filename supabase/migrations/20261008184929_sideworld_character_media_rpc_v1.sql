-- SIDEWORLD Character Media RPC V1. Additive; deploy to staging first.
-- Keep canon/universe schemas private. Both functions are service-role-only.
create or replace function public.sideworld_character_media_gallery(p_universe_slug text, p_franchise_slug text)
returns jsonb language sql stable security definer set search_path = pg_catalog, public
as $$
  with selected as (
    select c.id, c.slug, c.name, c.canon_status
    from canon.characters c
    join canon.franchises f on f.id = c.franchise_id
    join universe.universes u on u.id = f.universe_id
    where u.slug = p_universe_slug and f.slug = p_franchise_slug
  )
  select jsonb_build_object(
    'characters', coalesce((select jsonb_agg(to_jsonb(c) order by c.name) from selected c), '[]'::jsonb),
    'assets', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id, 'character_id', a.character_id, 'visual_version', a.visual_version,
        'asset_role', a.asset_role, 'approval_status', a.approval_status,
        'source_sha256', a.source_sha256, 'storage_path', a.storage_path,
        'source_document', a.source_document, 'rights_note', a.rights_note,
        'approved_at', a.approved_at, 'created_at', a.created_at
      ) order by a.created_at desc)
      from canon.character_visual_assets a join selected c on c.id = a.character_id
    ), '[]'::jsonb)
  );
$$;

create or replace function public.sideworld_character_media_approve(
  p_universe_slug text, p_franchise_slug text, p_asset_id uuid,
  p_character_id uuid, p_expected_sha256 text, p_rights_note text, p_reviewer_id uuid
) returns boolean language plpgsql security definer set search_path = pg_catalog, public
as $$
declare v_updated uuid;
begin
  if length(btrim(p_rights_note)) < 20 or length(p_rights_note) > 1000 then
    raise exception 'Invalid rights statement' using errcode = '22023';
  end if;
  if not exists (select 1 from auth.users where id = p_reviewer_id) then
    raise exception 'Unknown reviewer' using errcode = '22023';
  end if;
  update canon.character_visual_assets a
  set approval_status = 'approved', approved_by = p_reviewer_id,
      approved_at = now(), rights_note = btrim(p_rights_note)
  where a.id = p_asset_id and a.character_id = p_character_id
    and a.source_sha256 = p_expected_sha256 and a.approval_status = 'draft'
    and a.asset_role = 'canonical_portrait'
    and exists (
      select 1 from canon.characters c
      join canon.franchises f on f.id = c.franchise_id
      join universe.universes u on u.id = f.universe_id
      where c.id = a.character_id and f.slug = p_franchise_slug and u.slug = p_universe_slug
    )
  returning a.id into v_updated;
  return v_updated is not null;
end;
$$;

revoke all on function public.sideworld_character_media_gallery(text,text) from public, anon, authenticated;
revoke all on function public.sideworld_character_media_approve(text,text,uuid,uuid,text,text,uuid) from public, anon, authenticated;
grant execute on function public.sideworld_character_media_gallery(text,text) to service_role;
grant execute on function public.sideworld_character_media_approve(text,text,uuid,uuid,text,text,uuid) to service_role;
