-- SIDEWORLD real-account private releases V1 (additive).
-- No QA accounts, no expiry, no open publication.
-- Existing private_qa releases and their historical access work unchanged.
-- This is an auth/RLS-sensitive migration. Rehearse in isolation and verify
-- a fresh encrypted production backup + successful restore before applying.

-- Extend the existing visibility enum-as-check without losing original rows.
alter table canon.quest_releases
  add constraint sw_release_visibility_v2
  check (visibility in ('private','private_qa','published','retired')) not valid;
alter table canon.quest_releases validate constraint sw_release_visibility_v2;
alter table canon.quest_releases drop constraint quest_releases_visibility_check;
alter table canon.quest_releases rename constraint sw_release_visibility_v2 to quest_releases_visibility_check;

-- An existing Supabase Auth account is the identity. No special tester user,
-- time window, expiry or browser-controlled release hash.
create table player.private_access (
 release_id uuid not null references canon.quest_releases(id) on delete restrict,
 actor_id uuid not null references auth.users(id) on delete cascade,
 granted_by uuid not null references auth.users(id) on delete restrict,
 granted_at timestamptz not null default now(),
 revoked_at timestamptz,
 revoked_by uuid references auth.users(id) on delete restrict,
 primary key(release_id,actor_id)
);
create index private_access_actor_idx on player.private_access(actor_id,release_id)
 where revoked_at is null;
alter table player.private_access enable row level security;
revoke all on player.private_access from public,anon,authenticated,service_role;

-- Existing OWNER/ADMIN accounts can access all private drafts they manage.
-- Additional real users may access ONLY if explicitly entitled, forever
-- until revoked. The legacy QA mechanism is preserved for existing runs.
create or replace function player.can_use_release_v1(p_actor uuid,p_release uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select coalesce(p_actor is not null and exists(
   select 1 from canon.quest_releases r where r.id=p_release and (
    (r.visibility='published' and r.editorial_approved_at is not null
      and r.field_verified_at is not null and r.media_cleared_at is not null
      and r.published_at is not null)
    or (r.visibility='private_qa' and exists(
      select 1 from player.qa_access g where g.release_id=r.id
       and g.actor_id=p_actor and g.expires_at>now() and g.revoked_at is null))
    or (r.visibility='private' and (
      exists(select 1 from shared.user_roles u where u.user_id=p_actor
       and u.role::text in ('OWNER','ADMIN'))
      or exists(select 1 from player.private_access a where a.release_id=r.id
       and a.actor_id=p_actor and a.revoked_at is null)
    ))
   )
 ),false);
$$;

-- Service-only release creation. Only real OWNER/ADMIN identities; immutable
-- reviewed draft snapshot and supplied canonical Player content hash.
-- Studio computes hash server-side from the exact pinned Player V1 contract;
-- Player independently validates it on every load/start.
create function public.sideworld_player_private_release_create_v1(
 p_actor uuid,p_draft uuid,p_revision integer,p_engine_content_hash text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d jsonb; diagnostics jsonb; status text; prior canon.quest_releases; ident uuid;
begin
 if p_actor is null or p_draft is null or p_revision is null or p_revision<=0
   or p_engine_content_hash is null or
   p_engine_content_hash !~ '^[0-9a-f]{64}$' then
   return jsonb_build_object('kind','invalid');
 end if;
 if not exists(select 1 from shared.user_roles where user_id=p_actor
   and role::text in ('OWNER','ADMIN')) then
   return jsonb_build_object('kind','unavailable');
 end if;
 select r.document,r.diagnostics,q.status into d,diagnostics,status
 from canon.quest_drafts q join canon.quest_draft_revisions r on r.draft_id=q.id
 where q.id=p_draft and q.revision>=p_revision and r.revision=p_revision;
 if d is null or status<>'draft' or jsonb_typeof(diagnostics) is distinct from 'array'
   or exists(select 1 from jsonb_array_elements(diagnostics) x where x->>'severity'='error') then
   return jsonb_build_object('kind','unavailable');
 end if;
 insert into canon.quest_releases(source_draft_id,source_revision,document,
    engine_content_hash,visibility,created_by)
 values(p_draft,p_revision,d,p_engine_content_hash,'private',p_actor)
 on conflict(source_draft_id,source_revision) do nothing returning id into ident;
 if ident is not null then return jsonb_build_object('kind','created','releaseId',ident); end if;
 select * into prior from canon.quest_releases
   where source_draft_id=p_draft and source_revision=p_revision;
 if prior.id is null or prior.visibility<>'private'
   or prior.engine_content_hash<>p_engine_content_hash or prior.document is distinct from d then
   return jsonb_build_object('kind','conflict');
 end if;
 return jsonb_build_object('kind','existing','releaseId',prior.id);
end $$;

-- Simple real-account entitlement, no expiry. Auth.users must already exist.
-- It is deliberately NOT a public release nor a QA tester grant.
create function public.sideworld_player_private_access_set_v1(
 p_actor uuid,p_release uuid,p_user uuid,p_allow boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if p_actor is null or p_release is null or p_user is null or p_allow is null
   or not exists(select 1 from shared.user_roles where user_id=p_actor
     and role::text in ('OWNER','ADMIN'))
   or not exists(select 1 from canon.quest_releases where id=p_release
     and visibility='private')
   or not exists(select 1 from auth.users where id=p_user) then
   return jsonb_build_object('kind','unavailable');
 end if;
 if p_allow then
   insert into player.private_access(release_id,actor_id,granted_by,revoked_at,revoked_by)
   values(p_release,p_user,p_actor,null,null)
   on conflict(release_id,actor_id) do update set granted_by=excluded.granted_by,
    revoked_at=null,revoked_by=null;
   return jsonb_build_object('kind','granted','releaseId',p_release,'userId',p_user);
 end if;
 update player.private_access set revoked_at=now(),revoked_by=p_actor
 where release_id=p_release and actor_id=p_user and revoked_at is null;
 return jsonb_build_object('kind','revoked','releaseId',p_release,'userId',p_user);
end $$;

revoke all on function public.sideworld_player_private_release_create_v1(uuid,uuid,integer,text)
 from public,anon,authenticated;
revoke all on function public.sideworld_player_private_access_set_v1(uuid,uuid,uuid,boolean)
 from public,anon,authenticated;
grant execute on function public.sideworld_player_private_release_create_v1(uuid,uuid,integer,text)
 to service_role;
grant execute on function public.sideworld_player_private_access_set_v1(uuid,uuid,uuid,boolean)
 to service_role;

-- Rollback: revoke these two new functions and remove the private branch
-- from can_use_release_v1; preserve private_access and 'private' records so
-- original quest runs/data survive. Never drop private release records.
