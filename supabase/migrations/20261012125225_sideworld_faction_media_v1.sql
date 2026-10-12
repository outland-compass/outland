-- Owned by outland-compass/outland. Private faction illustrations; no character duplication.
create table canon.faction_visual_assets (
 id uuid primary key default gen_random_uuid(),
 faction_id uuid not null references canon.factions(id) on delete restrict,
 visual_version integer not null check (visual_version > 0),
 asset_role text not null check (asset_role in ('canonical_illustration','symbol','reference_sheet')),
 storage_bucket text not null default 'sideworld-faction-media' check (storage_bucket='sideworld-faction-media'),
 storage_path text not null unique check (storage_path !~ '(^/|\.\.|//)' and length(storage_path)<=500),
 source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
 source_document text not null,
 source_part text not null,
 approval_status text not null default 'draft' check (approval_status in ('draft','approved','retired')),
 approved_by uuid references auth.users(id) on delete restrict,
 approved_at timestamptz,
 rights_note text not null,
 created_at timestamptz not null default now(),
 unique(faction_id,visual_version,asset_role),
 check ((approval_status='approved' and approved_by is not null and approved_at is not null) or
        (approval_status<>'approved' and approved_by is null and approved_at is null))
);
create index faction_visual_assets_approved_by_idx on canon.faction_visual_assets(approved_by);
create unique index faction_visual_assets_current_idx on canon.faction_visual_assets(faction_id,asset_role) where approval_status='approved';
alter table canon.faction_visual_assets enable row level security;
revoke all on canon.faction_visual_assets from public,anon,authenticated,service_role;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('sideworld-faction-media','sideworld-faction-media',false,10485760,array['image/png','image/jpeg','image/webp'])
on conflict(id) do nothing;
create function public.sideworld_faction_media_gallery(p_universe_slug text,p_franchise_slug text)
returns jsonb language sql stable security definer set search_path=pg_catalog,public as $$
with selected as (
 select x.id,x.slug,x.name,x.description,x.visibility,x.canon_status,x.metadata
 from canon.factions x join canon.franchises f on f.id=x.franchise_id
 join universe.universes u on u.id=f.universe_id
 where u.slug=p_universe_slug and f.slug=p_franchise_slug
)
select jsonb_build_object(
 'factions',coalesce((select jsonb_agg(jsonb_build_object(
  'id',x.id,'slug',x.slug,'name',x.name,'description',x.description,
  'visibility',x.visibility,'canon_status',x.canon_status,
  'parent_slug',x.metadata->>'parent_faction_slug',
  'memberships',coalesce(x.metadata->'memberships','[]'::jsonb),
  'symbol_status',x.metadata->'symbol'->>'status') order by x.name) from selected x),'[]'::jsonb),
 'assets',coalesce((select jsonb_agg(jsonb_build_object(
  'id',a.id,'faction_id',a.faction_id,'visual_version',a.visual_version,
  'asset_role',a.asset_role,'approval_status',a.approval_status,
  'storage_path',a.storage_path,'source_sha256',a.source_sha256,
  'source_document',a.source_document,'source_part',a.source_part,
  'rights_note',a.rights_note,'approved_at',a.approved_at) order by a.created_at desc)
  from canon.faction_visual_assets a join selected x on x.id=a.faction_id
  where a.approval_status='approved' and x.canon_status='approved'),'[]'::jsonb)
);
$$;
revoke all on function public.sideworld_faction_media_gallery(text,text) from public,anon,authenticated;
grant execute on function public.sideworld_faction_media_gallery(text,text) to service_role;
comment on function public.sideworld_faction_media_gallery(text,text) is 'Private Studio server-only scoped lookup. Never granted to browser roles.';
