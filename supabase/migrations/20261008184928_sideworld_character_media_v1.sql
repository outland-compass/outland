-- SIDEWORLD Character Media V1 (additive, production requires backup/restore verification).
-- Private original portraits are never made public through storage.objects policies.
-- Server-side uploads must verify source SHA-256 before writing.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('sideworld-character-media', 'sideworld-character-media', false, 10485760, array['image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

create table if not exists canon.character_visual_assets (
  id uuid primary key default gen_random_uuid(),
  character_id uuid not null references canon.characters(id) on delete restrict,
  visual_version integer not null check (visual_version > 0),
  asset_role text not null check (asset_role in ('canonical_portrait','reference_sheet','expression','pose')),
  storage_bucket text not null default 'sideworld-character-media'
    check (storage_bucket = 'sideworld-character-media'),
  storage_path text not null unique,
  source_sha256 text not null check (source_sha256 ~ '^[a-f0-9]{64}$'),
  source_document text,
  source_part text,
  approval_status text not null default 'draft'
    check (approval_status in ('draft','approved','retired')),
  approved_by uuid references auth.users(id) on delete restrict,
  approved_at timestamptz,
  rights_note text not null,
  created_at timestamptz not null default now(),
  constraint character_visual_asset_approval_consistency check (
    (approval_status = 'approved' and approved_by is not null and approved_at is not null)
    or (approval_status <> 'approved' and approved_by is null and approved_at is null)
  ),
  constraint character_visual_asset_storage_path_safe check (
    storage_path !~ '(^/|\.\.|//)' and length(storage_path) <= 500
  )
);
create unique index if not exists character_one_approved_portrait_per_version
  on canon.character_visual_assets (character_id, visual_version)
  where asset_role = 'canonical_portrait' and approval_status = 'approved';
create index if not exists character_visual_assets_character_version
  on canon.character_visual_assets(character_id, visual_version);
alter table canon.character_visual_assets enable row level security;
revoke all on canon.character_visual_assets from anon, authenticated;
-- No client policies: server-only operations after owner auth. Service role bypasses RLS.
-- No storage.objects policies for the new bucket: only trusted server-side access.
comment on table canon.character_visual_assets is
  'Immutable-source character artwork references; existing canon.characters is canonical. No public client write access.';
