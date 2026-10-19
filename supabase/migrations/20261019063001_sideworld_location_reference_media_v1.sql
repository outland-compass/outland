-- SIDEWORLD location reference media V1: additive, private, reusable cross-quest photographic evidence.
-- No existing records changed; uploads/reviews use server-only service RPCs.
create table geo.location_media (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references geo.locations(id) on delete restrict,
  source_id uuid references geo.sources(id) on delete set null,
  storage_bucket text not null default 'sideworld-location-media' check (storage_bucket='sideworld-location-media'),
  storage_path text not null unique,
  source_sha256 text not null check (source_sha256 ~ '^[0-9a-f]{64}$'),
  mime_type text not null check (mime_type in ('image/jpeg','image/png','image/webp')),
  byte_length integer not null check (byte_length between 1 and 10485760),
  media_role text not null check (media_role in ('primary','reference','detail')),
  alt_text text not null check (length(btrim(alt_text)) between 10 and 500),
  viewpoint_notes text not null default '' check (length(viewpoint_notes)<=1000),
  rights_basis text not null default 'unknown' check (rights_basis in ('owned','licensed','permission','unknown')),
  rights_note text not null check (length(btrim(rights_note)) between 12 and 2000),
  verification_status text not null default 'pending' check (verification_status in ('pending','verified','rejected')),
  ai_usage_allowed boolean not null default false,
  created_by uuid not null references auth.users(id),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint location_media_ai_approval check (not ai_usage_allowed or (verification_status='verified' and rights_basis<>'unknown')),
  constraint location_media_review_consistent check (verification_status='pending' or (reviewed_by is not null and reviewed_at is not null))
);
create index location_media_location_status_idx on geo.location_media(location_id,verification_status,media_role);
create unique index location_media_one_verified_primary_idx on geo.location_media(location_id) where media_role='primary' and verification_status='verified';
comment on table geo.location_media is 'Cross-quest real-world reference photography; never treat generated puzzle artwork as geographic evidence.';
alter table geo.location_media enable row level security;
revoke all on geo.location_media from public, anon, authenticated, service_role;
grant select,insert,update on geo.location_media to service_role;
-- Private Storage: upload only through authenticated Studio server; no end-user object policies.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('sideworld-location-media','sideworld-location-media',false,10485760,array['image/jpeg','image/png','image/webp']::text[])
on conflict (id) do nothing;

create function public.sideworld_location_media_list(p_city_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
select coalesce(jsonb_agg(jsonb_build_object(
  'id',m.id,'locationId',m.location_id,'sourceId',m.source_id,
  'role',m.media_role,'altText',m.alt_text,'viewpointNotes',m.viewpoint_notes,
  'rightsBasis',m.rights_basis,'rightsNote',m.rights_note,
  'verificationStatus',m.verification_status,'aiUsageAllowed',m.ai_usage_allowed,
  'sha256',m.source_sha256,'mimeType',m.mime_type,'createdAt',m.created_at
) order by m.created_at,m.id),'[]'::jsonb)
from geo.location_media m join geo.locations l on l.id=m.location_id where l.city_id=p_city_id
$$;
create function public.sideworld_location_media_private(p_asset_id uuid)
returns jsonb language sql stable security definer set search_path='' as $$
select jsonb_build_object('id',m.id,'locationId',m.location_id,'storageBucket',m.storage_bucket,
  'storagePath',m.storage_path,'sha256',m.source_sha256,'mimeType',m.mime_type,'byteLength',m.byte_length,
  'verificationStatus',m.verification_status,'aiUsageAllowed',m.ai_usage_allowed)
from geo.location_media m where m.id=p_asset_id
$$;
create function public.sideworld_location_media_register(
  p_location_id uuid,p_source_id uuid,p_storage_path text,p_source_sha256 text,p_mime_type text,
  p_byte_length integer,p_media_role text,p_alt_text text,p_viewpoint_notes text,
  p_rights_basis text,p_rights_note text,p_actor uuid
) returns uuid language plpgsql security definer set search_path='' as $$
declare new_id uuid; extension text;
begin
  if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN')) then raise exception 'Admin required'; end if;
  if not exists(select 1 from geo.locations where id=p_location_id) then raise exception 'Location missing'; end if;
  if p_mime_type not in ('image/jpeg','image/png','image/webp') then raise exception 'Invalid image MIME'; end if;
  extension:=case p_mime_type when 'image/jpeg' then 'jpg' when 'image/png' then 'png' else 'webp' end;
  if p_source_sha256 !~ '^[0-9a-f]{64}$' or p_storage_path is distinct from p_location_id::text||'/'||p_source_sha256||'.'||extension
     or p_byte_length not between 1 and 10485760 then raise exception 'Invalid content address'; end if;
  if not exists(select 1 from storage.objects where bucket_id='sideworld-location-media' and name=p_storage_path)
    then raise exception 'Private original missing'; end if;
  insert into geo.location_media(location_id,source_id,storage_path,source_sha256,mime_type,byte_length,
      media_role,alt_text,viewpoint_notes,rights_basis,rights_note,created_by)
  values(p_location_id,p_source_id,p_storage_path,p_source_sha256,p_mime_type,p_byte_length,
      p_media_role,p_alt_text,p_viewpoint_notes,p_rights_basis,p_rights_note,p_actor)
  returning id into new_id;
  return new_id;
end $$;
create function public.sideworld_location_media_review(
  p_asset_id uuid,p_actor uuid,p_expected_sha256 text,p_decision text,p_ai_usage_allowed boolean
) returns boolean language plpgsql security definer set search_path='' as $$
declare m geo.location_media;
begin
  if not exists(select 1 from shared.user_roles where user_id=p_actor and role::text in ('OWNER','ADMIN')) then raise exception 'Admin required'; end if;
  select * into m from geo.location_media where id=p_asset_id for update;
  if not found or m.source_sha256 is distinct from p_expected_sha256 then raise exception 'Asset not found or changed'; end if;
  if p_decision not in ('verified','rejected') or (p_ai_usage_allowed and (p_decision<>'verified' or m.rights_basis='unknown'))
    then raise exception 'Invalid review or rights not cleared'; end if;
  update geo.location_media set verification_status=p_decision,ai_usage_allowed=p_ai_usage_allowed,
    reviewed_by=p_actor,reviewed_at=now() where id=p_asset_id;
  return true;
end $$;
-- RPCs are server-only and must not be callable with end-user JWTs.
revoke all on function public.sideworld_location_media_list(uuid) from public,anon,authenticated;
revoke all on function public.sideworld_location_media_private(uuid) from public,anon,authenticated;
revoke all on function public.sideworld_location_media_register(uuid,uuid,text,text,text,integer,text,text,text,text,text,uuid) from public,anon,authenticated;
revoke all on function public.sideworld_location_media_review(uuid,uuid,text,text,boolean) from public,anon,authenticated;
grant execute on function public.sideworld_location_media_list(uuid) to service_role;
grant execute on function public.sideworld_location_media_private(uuid) to service_role;
grant execute on function public.sideworld_location_media_register(uuid,uuid,text,text,text,integer,text,text,text,text,text,uuid) to service_role;
grant execute on function public.sideworld_location_media_review(uuid,uuid,text,text,boolean) to service_role;
