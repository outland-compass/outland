-- SIDEWORLD Player Runtime V1 — PROPOSAL ONLY. No production authorization.
-- Additive OUTLAND-owned migration. No backfill or existing table updates.
-- SECURITY: RPCs are server-only; Player API verifies JWT and derives actorId.
create schema if not exists player;
revoke all on schema player from public, anon, authenticated;

-- Immutable, canonical snapshot of an existing Studio draft revision.
create table canon.quest_releases (
  id uuid primary key default gen_random_uuid(),
  source_draft_id uuid not null,
  source_revision integer not null check (source_revision > 0),
  document jsonb not null check (jsonb_typeof(document)='object'
    and document->>'contractVersion'='1' and pg_column_size(document)<=250000),
  engine_content_hash text not null check (engine_content_hash ~ '^[0-9a-f]{64}$'),
  visibility text not null default 'private_qa'
    check (visibility in ('private_qa','published','retired')),
  editorial_approved_at timestamptz,
  field_verified_at timestamptz,
  media_cleared_at timestamptz,
  published_at timestamptz,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint sw_release_source_fk foreign key (source_draft_id,source_revision)
    references canon.quest_draft_revisions(draft_id,revision) on delete restrict,
  constraint sw_release_source_unique unique (source_draft_id,source_revision),
  constraint sw_release_publication_gate check (
    visibility <> 'published' or
    (editorial_approved_at is not null and field_verified_at is not null
     and media_cleared_at is not null and published_at is not null)
  )
);
create index sw_release_visibility_idx on canon.quest_releases(visibility,id);
comment on table canon.quest_releases is
  'Canonical immutable SIDEWORLD snapshots with PRIVATE answer keys; never client-readable.';

-- Keep source, content and engine hash immutable even when release visibility changes.
-- No release writing/approval function is included in this proposal.
create function canon.sideworld_guard_release_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare authored jsonb;
begin
  if TG_OP='DELETE' then raise exception 'Quest release deletion is disabled'; end if;
  if TG_OP='UPDATE' then
    if new.id is distinct from old.id or
       new.source_draft_id is distinct from old.source_draft_id or
       new.source_revision is distinct from old.source_revision or
       new.document is distinct from old.document or
       new.engine_content_hash is distinct from old.engine_content_hash or
       new.created_by is distinct from old.created_by or
       new.created_at is distinct from old.created_at then
      raise exception 'Quest release content and source are immutable';
    end if;
    if (old.visibility='retired' and new.visibility <> 'retired')
       or (old.visibility='published' and new.visibility='private_qa') then
      raise exception 'Invalid release lifecycle transition';
    end if;
    new.updated_at:=now();
    return new;
  end if;
  select r.document into authored from canon.quest_draft_revisions r
  where r.draft_id=new.source_draft_id and r.revision=new.source_revision;
  if authored is null or authored is distinct from new.document then
    raise exception 'Release must be a frozen copy of the exact Studio revision';
  end if;
  return new;
end $$;
create trigger sideworld_release_v1_guard
before insert or update or delete on canon.quest_releases
for each row execute function canon.sideworld_guard_release_v1();

-- Ordinary QA users are NOT Studio administrators; grants expire and can be revoked.
create table player.qa_access (
  release_id uuid not null references canon.quest_releases(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete cascade,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  granted_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  primary key (release_id,actor_id),
  constraint sw_qa_expiry_after_creation check (expires_at > created_at)
);
create index sw_qa_actor_lookup on player.qa_access(actor_id,release_id);

-- Store only server-created event histories, bound to immutable versions.
create table player.quest_runs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id) on delete restrict,
  release_id uuid not null references canon.quest_releases(id) on delete restrict,
  start_request_id uuid not null,
  sequence integer not null default 0 check (sequence between 0 and 10000),
  engine_content_hash text not null check (engine_content_hash ~ '^[0-9a-f]{64}$'),
  progress jsonb not null check (jsonb_typeof(progress)='object'
    and pg_column_size(progress)<=262144),
  status text not null default 'in_progress' check (status in ('in_progress','completed','abandoned')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(actor_id,release_id,start_request_id)
);
create index sw_runs_actor_recent on player.quest_runs(actor_id,updated_at desc);
create index sw_runs_release_idx on player.quest_runs(release_id);

-- Bounded recent receipts: retries cannot cause duplicate unlocks/advances.
create table player.run_receipts (
  run_id uuid not null references player.quest_runs(id) on delete cascade,
  request_id uuid not null,
  fingerprint text not null check (fingerprint ~ '^[0-9a-f]{64}$'),
  result_sequence integer not null check (result_sequence between 1 and 10000),
  result_progress jsonb not null check (jsonb_typeof(result_progress)='object'
    and pg_column_size(result_progress)<=262144),
  created_at timestamptz not null default now(),
  primary key (run_id,request_id)
);
create index sw_receipts_recent on player.run_receipts(run_id,result_sequence desc);

alter table canon.quest_releases enable row level security;
alter table player.qa_access enable row level security;
alter table player.quest_runs enable row level security;
alter table player.run_receipts enable row level security;
-- Intentionally zero policies and zero direct API grants.
revoke all on canon.quest_releases,player.qa_access,player.quest_runs,player.run_receipts
  from public,anon,authenticated,service_role;
revoke all on function canon.sideworld_guard_release_v1()
  from public,anon,authenticated,service_role;

-- Internal entitlement check; not exposed as a client function.
create function player.can_use_release_v1(p_actor uuid,p_release uuid)
returns boolean language sql stable security definer set search_path='' as $$
  select exists (
    select 1 from canon.quest_releases r where r.id=p_release and (
      (r.visibility='published' and r.editorial_approved_at is not null
       and r.field_verified_at is not null and r.media_cleared_at is not null
       and r.published_at is not null)
      or (r.visibility='private_qa' and exists (
        select 1 from player.qa_access g where g.release_id=r.id
          and g.actor_id=p_actor and g.expires_at>now() and g.revoked_at is null
      ))
    )
  );
$$;
revoke all on function player.can_use_release_v1(uuid,uuid)
  from public,anon,authenticated,service_role;

-- Returns FULL answer-key-bearing document to trusted service code only.
create function public.sideworld_player_release_get_v1(p_actor uuid,p_release_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare r canon.quest_releases;
begin
  if p_actor is null or not player.can_use_release_v1(p_actor,p_release_id) then return null; end if;
  select * into r from canon.quest_releases where id=p_release_id;
  if not found then return null; end if;
  return jsonb_build_object('versionId',r.id,'questId',r.source_draft_id,
    'revision',r.source_revision,'visibility',r.visibility,
    'contentHash',r.engine_content_hash,'document',r.document);
end $$;

-- Start is idempotent for actor/release/request_id.
create function public.sideworld_player_run_start_v1(
  p_actor uuid,p_release_id uuid,p_request_id uuid,p_initial_progress jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare r canon.quest_releases; v player.quest_runs;
begin
  if p_actor is null or p_request_id is null
     or not player.can_use_release_v1(p_actor,p_release_id) then
    return jsonb_build_object('kind','unavailable');
  end if;
  select * into r from canon.quest_releases where id=p_release_id;
  if r.id is null or p_initial_progress is null
     or jsonb_typeof(p_initial_progress)<>'object'
     or pg_column_size(p_initial_progress)>262144
     or p_initial_progress->'engineVersion' is distinct from '1'::jsonb
     or p_initial_progress->>'questId' is distinct from r.source_draft_id::text
     or p_initial_progress->'revision' is distinct from to_jsonb(r.source_revision)
     or p_initial_progress->>'contentHash' is distinct from r.engine_content_hash
     or p_initial_progress->'sequence' is distinct from '0'::jsonb
     or p_initial_progress->'events' is distinct from '[]'::jsonb then
    return jsonb_build_object('kind','invalid');
  end if;
  insert into player.quest_runs(actor_id,release_id,start_request_id,engine_content_hash,progress)
    values(p_actor,p_release_id,p_request_id,r.engine_content_hash,p_initial_progress)
    on conflict (actor_id,release_id,start_request_id) do nothing
    returning * into v;
  if v.id is null then
    select * into v from player.quest_runs
    where actor_id=p_actor and release_id=p_release_id and start_request_id=p_request_id;
  end if;
  return jsonb_build_object('kind','started','runId',v.id,'versionId',v.release_id,
    'actorId',v.actor_id,'status',v.status,'sequence',v.sequence,'progress',v.progress);
end $$;

-- Actor-scoped trusted run lookup, not accessible to browser roles.
create function public.sideworld_player_run_get_v1(p_actor uuid,p_run_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare v player.quest_runs;
begin
  select * into v from player.quest_runs where id=p_run_id and actor_id=p_actor;
  if v.id is null or not player.can_use_release_v1(p_actor,v.release_id) then return null; end if;
  return jsonb_build_object('runId',v.id,'versionId',v.release_id,
    'actorId',v.actor_id,'status',v.status,'sequence',v.sequence,'progress',v.progress);
end $$;

-- Lock, receipt lookup, compare, append and receipt write in ONE DB transaction.
-- The server validates the deterministic Player transition before calling this RPC.
create function public.sideworld_player_run_apply_v1(
  p_actor uuid,p_run_id uuid,p_request_id uuid,p_fingerprint text,
  p_expected_sequence integer,p_next_progress jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare v player.quest_runs; prior player.run_receipts;
begin
  if p_actor is null or p_run_id is null or p_request_id is null
     or p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{64}$'
     or p_expected_sequence is null or p_expected_sequence<0 then
    return jsonb_build_object('kind','invalid');
  end if;
  select * into v from player.quest_runs
    where id=p_run_id and actor_id=p_actor for update;
  if v.id is null or not player.can_use_release_v1(p_actor,v.release_id) then
    return jsonb_build_object('kind','unavailable');
  end if;
  select * into prior from player.run_receipts
    where run_id=p_run_id and request_id=p_request_id;
  if prior.run_id is not null then
    if prior.fingerprint <> p_fingerprint then
      return jsonb_build_object('kind','conflict');
    end if;
    return jsonb_build_object('kind','duplicate','runId',v.id,'versionId',v.release_id,
      'actorId',v.actor_id,'status',v.status,'sequence',prior.result_sequence,
      'progress',prior.result_progress);
  end if;
  if v.status <> 'in_progress' or p_expected_sequence <> v.sequence or v.sequence>=10000 then
    return jsonb_build_object('kind','conflict');
  end if;
  if p_next_progress is null or jsonb_typeof(p_next_progress)<>'object'
     or pg_column_size(p_next_progress)>262144
     or p_next_progress->'engineVersion' is distinct from '1'::jsonb
     or p_next_progress->>'questId' is distinct from v.progress->>'questId'
     or p_next_progress->'revision' is distinct from v.progress->'revision'
     or p_next_progress->>'contentHash' is distinct from v.engine_content_hash
     or p_next_progress->'sequence' is distinct from to_jsonb(p_expected_sequence+1)
     or jsonb_typeof(p_next_progress->'events') is distinct from 'array'
     or jsonb_typeof(v.progress->'events') is distinct from 'array' then
    return jsonb_build_object('kind','invalid');
  end if;
  if jsonb_array_length(p_next_progress->'events') <> p_expected_sequence+1
     or (p_next_progress->'events' - p_expected_sequence)
          is distinct from (v.progress->'events') then
    return jsonb_build_object('kind','invalid');
  end if;
  update player.quest_runs set progress=p_next_progress,sequence=p_expected_sequence+1,
      updated_at=now() where id=v.id;
  insert into player.run_receipts(run_id,request_id,fingerprint,result_sequence,result_progress)
    values(v.id,p_request_id,p_fingerprint,p_expected_sequence+1,p_next_progress);
  delete from player.run_receipts where run_id=v.id and request_id in (
    select request_id from player.run_receipts where run_id=v.id
    order by result_sequence desc offset 16
  );
  return jsonb_build_object('kind','saved','runId',v.id,'versionId',v.release_id,
    'actorId',v.actor_id,'status',v.status,'sequence',p_expected_sequence+1,
    'progress',p_next_progress);
end $$;

-- PUBLIC has default EXECUTE on new functions unless revoked explicitly.
revoke all on function public.sideworld_player_release_get_v1(uuid,uuid),
  public.sideworld_player_run_start_v1(uuid,uuid,uuid,jsonb),
  public.sideworld_player_run_get_v1(uuid,uuid),
  public.sideworld_player_run_apply_v1(uuid,uuid,uuid,text,integer,jsonb)
  from public,anon,authenticated,service_role;
grant execute on function public.sideworld_player_release_get_v1(uuid,uuid),
  public.sideworld_player_run_start_v1(uuid,uuid,uuid,jsonb),
  public.sideworld_player_run_get_v1(uuid,uuid),
  public.sideworld_player_run_apply_v1(uuid,uuid,uuid,text,integer,jsonb)
  to service_role;

comment on schema player is 'SIDEWORLD consumer gameplay runtime, separate from OUTLAND Passport.';
comment on table player.quest_runs is 'Actor-owned private event history and immutable quest-version binding.';
comment on table player.run_receipts is 'Bounded atomic idempotency receipts for gameplay.';
comment on table player.qa_access is 'Expiring field-test entitlement independent of Studio roles.';
