-- SIDEWORLD City Deep Research dossier checkpoint V1.
-- ONE versioned, franchise-neutral city intelligence snapshot per founder+city.
-- Additive only: no mutation to existing cities, facts, locations, universes,
-- franchises, QuestDrafts, OUTLAND worlds or Player visibility.
--
-- DO NOT APPLY to production without explicit approval, verified recent backup,
-- restore readiness, and the companion Studio validation/feature-flag PR.
-- No data is automatically imported into canonical GEO.
create table geo.city_research_dossiers (
  id uuid primary key default gen_random_uuid(),
  city_id uuid not null references geo.cities(id) on delete restrict,
  owner_id uuid not null references auth.users(id) on delete restrict,
  research_version text not null default 'sideworld.city-deep-research-dossier.v1'
    check (research_version='sideworld.city-deep-research-dossier.v1'),
  status text not null default 'partial'
    check (status in ('partial','source_research_complete')),
  revision integer not null default 1 check (revision>=1),
  snapshot jsonb not null check (
    jsonb_typeof(snapshot)='object' and
    pg_column_size(snapshot)<=1200000 and
    snapshot->>'kind'='sideworld.city-deep-research-dossier.v1' and
    snapshot->>'fieldVerified'='false' and
    snapshot->>'readyToImport'='false' and
    jsonb_typeof(snapshot->'batches')='array' and
    jsonb_typeof(snapshot->'completedQueryKeys')='array' and
    jsonb_array_length(snapshot->'completedQueryKeys')<=32
  ),
  snapshot_sha256 text not null check(snapshot_sha256 ~ '^[a-f0-9]{64}$'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(city_id,owner_id,research_version)
);
create index city_research_dossiers_by_city on geo.city_research_dossiers(city_id,updated_at desc);
alter table geo.city_research_dossiers enable row level security;
revoke all on table geo.city_research_dossiers from public,anon,authenticated,service_role;

-- Both RPCs are service-role only. The actor must exist and be OWNER/ADMIN,
-- and Studio still independently enforces a founder-only account on the
-- request. No public, authenticated or anonymous direct table access.
create function public.sideworld_city_research_dossier_get_v1(
  p_city_id uuid,p_actor uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare row_data geo.city_research_dossiers;
begin
  if p_actor is null or p_city_id is null or not exists(
    select 1 from shared.user_roles r
    where r.user_id=p_actor and r.role::text in ('OWNER','ADMIN')
  ) then raise exception 'Admin required'; end if;
  select * into row_data from geo.city_research_dossiers
    where city_id=p_city_id and owner_id=p_actor
      and research_version='sideworld.city-deep-research-dossier.v1';
  if not found then return null; end if;
  return jsonb_build_object('cityId',row_data.city_id,'revision',row_data.revision,
    'snapshot',row_data.snapshot,'hash',row_data.snapshot_sha256,
    'status',row_data.status,'updatedAt',row_data.updated_at);
end $$;

create function public.sideworld_city_research_dossier_save_v1(
  p_city_id uuid,p_actor uuid,p_expected_revision integer,
  p_snapshot jsonb,p_snapshot_sha256 text
) returns jsonb language plpgsql security definer set search_path='' as $$
declare existing geo.city_research_dossiers; new_revision integer;
begin
  if p_city_id is null or p_actor is null or p_expected_revision is null
    or p_expected_revision<0 or p_expected_revision>1000
    or p_snapshot is null or jsonb_typeof(p_snapshot)<>'object'
    or pg_column_size(p_snapshot)>1200000
    or p_snapshot->>'kind' is distinct from 'sideworld.city-deep-research-dossier.v1'
    or p_snapshot->>'fieldVerified' is distinct from 'false'
    or p_snapshot->>'readyToImport' is distinct from 'false'
    or p_snapshot#>>'{city,cityId}' is distinct from p_city_id::text
    or jsonb_typeof(p_snapshot->'batches') is distinct from 'array'
    or jsonb_typeof(p_snapshot->'completedQueryKeys') is distinct from 'array'
    or jsonb_array_length(p_snapshot->'completedQueryKeys')>32
    or p_snapshot->>'status' not in ('partial','source_research_complete')
    or p_snapshot_sha256 !~ '^[a-f0-9]{64}$'
  then raise exception 'Invalid research checkpoint'; end if;
  if not exists(select 1 from geo.cities where id=p_city_id and status<>'archived')
    or not exists(select 1 from shared.user_roles r
      where r.user_id=p_actor and r.role::text in ('OWNER','ADMIN'))
  then raise exception 'Active city and admin required'; end if;

  -- This advisory transaction lock prevents two initial inserts and retries
  -- for the same owner/city racing each other. No global contention.
  perform pg_advisory_xact_lock(hashtextextended(p_actor::text||':'||p_city_id::text,0));
  select * into existing from geo.city_research_dossiers
    where city_id=p_city_id and owner_id=p_actor
    and research_version='sideworld.city-deep-research-dossier.v1'
    for update;
  if not found then
    if p_expected_revision<>0 then raise exception 'Checkpoint revision conflict'; end if;
    insert into geo.city_research_dossiers(
      city_id,owner_id,research_version,status,revision,snapshot,snapshot_sha256
    ) values(
      p_city_id,p_actor,'sideworld.city-deep-research-dossier.v1',
      p_snapshot->>'status',1,p_snapshot,p_snapshot_sha256
    );
    return jsonb_build_object('revision',1,'status','saved');
  end if;
  -- An exact, already committed retry is idempotent. A stale DIFFERENT
  -- payload never overwrites a later research checkpoint.
  if existing.snapshot_sha256=p_snapshot_sha256
    and existing.snapshot=p_snapshot then
    return jsonb_build_object('revision',existing.revision,'status','unchanged');
  end if;
  if existing.revision<>p_expected_revision
    then raise exception 'Checkpoint revision conflict'; end if;
  new_revision:=existing.revision+1;
  update geo.city_research_dossiers set
    status=p_snapshot->>'status',revision=new_revision,
    snapshot=p_snapshot,snapshot_sha256=p_snapshot_sha256,updated_at=now()
  where id=existing.id;
  return jsonb_build_object('revision',new_revision,'status','saved');
end $$;

revoke all on function public.sideworld_city_research_dossier_get_v1(uuid,uuid)
  from public,anon,authenticated;
revoke all on function public.sideworld_city_research_dossier_save_v1(uuid,uuid,integer,jsonb,text)
  from public,anon,authenticated;
grant execute on function public.sideworld_city_research_dossier_get_v1(uuid,uuid)
  to service_role;
grant execute on function public.sideworld_city_research_dossier_save_v1(uuid,uuid,integer,jsonb,text)
  to service_role;

-- Controlled rollback, only if the feature was never activated:
-- DROP FUNCTION public.sideworld_city_research_dossier_save_v1(uuid,uuid,integer,jsonb,text);
-- DROP FUNCTION public.sideworld_city_research_dossier_get_v1(uuid,uuid);
-- DROP TABLE geo.city_research_dossiers;
-- If data exists, first export/retain dossier snapshots. Never silently drop
-- research results or revert unrelated SIDEWORLD/OUTLAND migrations.
