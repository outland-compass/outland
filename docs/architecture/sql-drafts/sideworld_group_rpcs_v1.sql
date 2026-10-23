-- SIDEWORLD GROUP RPCs — SECURITY DESIGN / SQL DRAFT, NOT A MIGRATION.
-- NEVER apply this file directly in production. Requires staging concurrency
-- tests, backup+restore readiness, RLS/grant audit, CI and explicit approval.
-- See sideworld_group_sessions_schema_v1.sql for the prerequisite schema.
--
-- Existing SIDEWORLD service-only RPC pattern:
-- public functions are SECURITY DEFINER, owned by postgres, search_path='',
-- execute granted to service_role ONLY; the Next.js server separately
-- authenticates JWT and derives p_actor from verified identity. A browser
-- supplied p_actor is NEVER trustworthy.
--
-- Important: SQL validates identity/entitlement/pins/CAS, but the trusted
-- Player engine MUST compute each next_progress and is_terminal.

begin;

-- One active host membership and a server-generated, short-lived invitation.
create function public.sideworld_group_create_v1(
  p_actor uuid, p_release_id uuid, p_mode text, p_request_id uuid,
  p_initial_progress jsonb, p_invite_hash text, p_invite_expires_at timestamptz
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
  r canon.quest_releases;
  s player.group_sessions;
  v_mode jsonb;
  v_roles jsonb;
  v_size integer;
  v_role text;
  v_new boolean := false;
begin
  if p_actor is null or p_release_id is null or p_request_id is null
    or p_mode not in ('couple','team')
    or p_invite_hash is null or p_invite_hash !~ '^[0-9a-f]{64}$'
    or p_invite_expires_at is null
    or p_invite_expires_at<=now()+interval '5 minutes'
    or p_invite_expires_at>now()+interval '24 hours'
    or not player.can_use_release_v1(p_actor,p_release_id)
  then return jsonb_build_object('kind','unavailable'); end if;

  select * into r from canon.quest_releases where id=p_release_id;
  if r.id is null or r.visibility not in ('private','private_qa','published')
  then return jsonb_build_object('kind','unavailable'); end if;

  v_mode:=r.document #> array['experienceModes',p_mode];
  v_roles:=v_mode->'roles';
  v_size:=jsonb_array_length(
    case when jsonb_typeof(v_roles)='array' then v_roles else '[]'::jsonb end
  );
  if v_mode->'minPlayers' is distinct from to_jsonb(v_size)
    or v_mode->'maxPlayers' is distinct from to_jsonb(v_size)
    or (p_mode='couple' and v_size<>2)
    or (p_mode='team' and v_size not in (3,4))
    or r.document #> '{experienceModes,version}' is distinct from '1'::jsonb
  then return jsonb_build_object('kind','invalid'); end if;

  v_role:=v_roles->0->>'id';
  if v_role is null or v_role !~ '^[a-z][a-z0-9_-]{0,39}$'
  then return jsonb_build_object('kind','invalid'); end if;

  if p_initial_progress is null
    or jsonb_typeof(p_initial_progress)<>'object'
    or pg_column_size(p_initial_progress)>262144
    or p_initial_progress->'engineVersion' is distinct from '1'::jsonb
    or p_initial_progress->>'questId' is distinct from r.source_draft_id::text
    or p_initial_progress->'revision' is distinct from to_jsonb(r.source_revision)
    or p_initial_progress->>'contentHash' is distinct from r.engine_content_hash
    or p_initial_progress->'sequence' is distinct from '0'::jsonb
    or p_initial_progress->'events' is distinct from '[]'::jsonb
  then return jsonb_build_object('kind','invalid'); end if;

  insert into player.group_sessions (
    release_id,host_actor_id,start_request_id,mode,expected_players,
    access_mode,engine_content_hash,progress,invite_hash,invite_expires_at
  ) values (
    r.id,p_actor,p_request_id,p_mode,v_size,r.visibility,
    r.engine_content_hash,p_initial_progress,p_invite_hash,p_invite_expires_at
  )
  on conflict (host_actor_id,release_id,start_request_id) do nothing
  returning * into s;

  if s.id is not null then
    v_new:=true;
    insert into player.group_members(session_id,actor_id,role_id)
      values(s.id,p_actor,v_role);
  else
    select * into s from player.group_sessions
      where host_actor_id=p_actor and release_id=p_release_id
        and start_request_id=p_request_id;
    if s.id is null or s.mode<>p_mode
      or s.engine_content_hash<>r.engine_content_hash
    then return jsonb_build_object('kind','conflict'); end if;
  end if;

  return jsonb_build_object('kind','started','sessionId',s.id,
    'versionId',s.release_id,'mode',s.mode,'status',s.status,
    'expectedPlayers',s.expected_players,'new',v_new);
end $fn$;

-- An invitation is proof of possession, NEVER proof of entitlement.
-- The HTTP route must hash the presented secret server-side; no browser
-- may select a role. The session row serializes competing joins.
create function public.sideworld_group_join_v1(
  p_actor uuid, p_session_id uuid, p_invite_hash text
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
  s player.group_sessions;
  member player.group_members;
  r canon.quest_releases;
  v_roles jsonb;
  v_role text;
  v_active integer;
begin
  if p_actor is null or p_session_id is null
  then return jsonb_build_object('kind','unavailable'); end if;

  select * into s from player.group_sessions
    where id=p_session_id for update;
  if s.id is null or s.status='abandoned'
    or not player.can_use_release_v1(p_actor,s.release_id)
  then return jsonb_build_object('kind','unavailable'); end if;

  select * into member from player.group_members
    where session_id=s.id and actor_id=p_actor;
  if member.session_id is not null then
    if member.left_at is not null then
      return jsonb_build_object('kind','unavailable');
    end if;
    return jsonb_build_object('kind','joined','sessionId',s.id,
      'roleId',member.role_id,'status',s.status);
  end if;

  if s.status<>'forming' or p_invite_hash is null
    or p_invite_hash !~ '^[0-9a-f]{64}$'
    or s.invite_hash is distinct from p_invite_hash
    or s.invite_expires_at<=now()
  then return jsonb_build_object('kind','unavailable'); end if;

  select * into r from canon.quest_releases where id=s.release_id;
  if r.id is null or r.engine_content_hash<>s.engine_content_hash
    or r.visibility<>s.access_mode
  then return jsonb_build_object('kind','unavailable'); end if;

  v_roles:=r.document #> array['experienceModes',s.mode,'roles'];
  if jsonb_typeof(v_roles)<>'array'
    or jsonb_array_length(v_roles)<>s.expected_players
  then return jsonb_build_object('kind','invalid'); end if;

  select count(*) into v_active from player.group_members
    where session_id=s.id and left_at is null;
  if v_active>=s.expected_players
  then return jsonb_build_object('kind','unavailable'); end if;

  select e.value->>'id' into v_role
  from jsonb_array_elements(v_roles) with ordinality as e(value,position)
  where not exists (
    select 1 from player.group_members m
    where m.session_id=s.id and m.role_id=e.value->>'id'
      and m.left_at is null
  ) order by e.position limit 1;

  if v_role is null or v_role !~ '^[a-z][a-z0-9_-]{0,39}$'
  then return jsonb_build_object('kind','invalid'); end if;

  insert into player.group_members(session_id,actor_id,role_id)
    values (s.id,p_actor,v_role);
  if v_active+1=s.expected_players then
    update player.group_sessions
      set status='in_progress',invite_hash=null,invite_expires_at=null,
          updated_at=now()
      where id=s.id;
  end if;

  return jsonb_build_object('kind','joined','sessionId',s.id,
    'roleId',v_role,'status',case when v_active+1=s.expected_players
    then 'in_progress' else 'forming' end);
end $fn$;

-- The RPC returns SERVER-PRIVATE progress to service_role only.
-- The trusted Player backend must project each actor's current view.
create function public.sideworld_group_get_v1(
  p_actor uuid, p_session_id uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare
  s player.group_sessions;
  m player.group_members;
  r canon.quest_releases;
  v_count integer;
begin
  if p_actor is null or p_session_id is null then return null; end if;
  select * into s from player.group_sessions where id=p_session_id;
  if s.id is null or s.status='abandoned'
    or not player.can_use_release_v1(p_actor,s.release_id)
  then return null; end if;
  select * into m from player.group_members
    where session_id=s.id and actor_id=p_actor and left_at is null;
  if m.session_id is null then return null; end if;
  select * into r from canon.quest_releases where id=s.release_id;
  if r.id is null or r.engine_content_hash<>s.engine_content_hash
    or r.visibility<>s.access_mode then return null; end if;
  select count(*) into v_count from player.group_members
    where session_id=s.id and left_at is null;

  return jsonb_build_object('sessionId',s.id,'actorId',p_actor,
    'versionId',s.release_id,'accessMode',s.access_mode,
    'mode',s.mode,'status',s.status,
    'roleId',m.role_id,'joinedPlayers',v_count,
    'expectedPlayers',s.expected_players,
    'engineContentHash',s.engine_content_hash,'progress',s.progress);
end $fn$;

create function public.sideworld_group_receipt_get_v1(
  p_actor uuid, p_session_id uuid, p_request_id uuid
) returns jsonb language plpgsql stable security definer set search_path='' as $fn$
declare
  s player.group_sessions;
  receipt player.group_receipts;
begin
  if p_actor is null or p_session_id is null or p_request_id is null
  then return null; end if;
  select * into s from player.group_sessions where id=p_session_id;
  if s.id is null or s.status='abandoned'
    or not player.can_use_release_v1(p_actor,s.release_id)
    or not exists(select 1 from player.group_members m
      where m.session_id=s.id and m.actor_id=p_actor and m.left_at is null)
  then return null; end if;
  select * into receipt from player.group_receipts
    where session_id=s.id and actor_id=p_actor and request_id=p_request_id;
  if receipt.session_id is null then return null; end if;
  return jsonb_build_object('fingerprint',receipt.fingerprint,
    'resultSequence',receipt.result_sequence,'status',receipt.result_status);
end $fn$;

-- CAS/idempotency are one transaction. Source content and actor access
-- are checked again inside the locked write; not just by Next.js.
create function public.sideworld_group_apply_v1(
  p_actor uuid,p_session_id uuid,p_request_id uuid,
  p_fingerprint text,p_expected_sequence integer,
  p_next_progress jsonb,p_is_terminal boolean
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
  s player.group_sessions;
  r canon.quest_releases;
  previous player.group_receipts;
  v_status text;
begin
  if p_actor is null or p_session_id is null or p_request_id is null
    or p_is_terminal is null or p_expected_sequence is null
    or p_expected_sequence<0 or p_expected_sequence>=10000
    or p_fingerprint is null or p_fingerprint !~ '^[0-9a-f]{64}$'
  then return jsonb_build_object('kind','invalid'); end if;

  select * into s from player.group_sessions
    where id=p_session_id for update;
  if s.id is null or s.status='abandoned'
    or not player.can_use_release_v1(p_actor,s.release_id)
    or not exists(select 1 from player.group_members m
      where m.session_id=s.id and m.actor_id=p_actor and m.left_at is null)
  then return jsonb_build_object('kind','unavailable'); end if;

  select * into r from canon.quest_releases where id=s.release_id;
  if r.id is null or r.engine_content_hash<>s.engine_content_hash
    or r.visibility<>s.access_mode
  then return jsonb_build_object('kind','unavailable'); end if;

  -- Check receipt BEFORE stale/terminal checks; exact committed retry must
  -- return original ACK even after another actor has advanced the session.
  select * into previous from player.group_receipts
    where session_id=s.id and request_id=p_request_id;
  if previous.session_id is not null then
    if previous.actor_id<>p_actor or previous.fingerprint<>p_fingerprint
    then return jsonb_build_object('kind','conflict'); end if;
    return jsonb_build_object('kind','duplicate',
      'resultSequence',previous.result_sequence,'status',previous.result_status);
  end if;

  if s.status<>'in_progress' or s.sequence<>p_expected_sequence
  then return jsonb_build_object('kind','conflict'); end if;

  if p_next_progress is null
    or jsonb_typeof(p_next_progress)<>'object'
    or pg_column_size(p_next_progress)>262144
    or p_next_progress->'engineVersion' is distinct from '1'::jsonb
    or p_next_progress->>'questId' is distinct from r.source_draft_id::text
    or p_next_progress->'revision' is distinct from to_jsonb(r.source_revision)
    or p_next_progress->>'contentHash' is distinct from s.engine_content_hash
    or p_next_progress->'sequence' is distinct from to_jsonb(s.sequence+1)
    or jsonb_typeof(p_next_progress->'events')<>'array'
    or jsonb_array_length(
        case when jsonb_typeof(p_next_progress->'events')='array'
          then p_next_progress->'events' else '[]'::jsonb end
      ) <> s.sequence+1
  then return jsonb_build_object('kind','invalid'); end if;

  v_status:=case when p_is_terminal then 'completed' else 'in_progress' end;
  update player.group_sessions
    set sequence=s.sequence+1,progress=p_next_progress,status=v_status,updated_at=now()
    where id=s.id;

  insert into player.group_receipts(
    session_id,request_id,actor_id,fingerprint,result_sequence,result_status
  ) values (s.id,p_request_id,p_actor,p_fingerprint,s.sequence+1,v_status);

  return jsonb_build_object('kind','saved',
    'resultSequence',s.sequence+1,'status',v_status);
end $fn$;

-- V1 explicitly does not allow silent host takeover or replacement during play.
-- Leaving/abandonment is idempotent; no destructive deletion of receipts.
create function public.sideworld_group_leave_v1(
  p_actor uuid,p_session_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $fn$
declare
  s player.group_sessions;
  m player.group_members;
begin
  if p_actor is null or p_session_id is null
  then return jsonb_build_object('kind','unavailable'); end if;
  select * into s from player.group_sessions where id=p_session_id for update;
  if s.id is null then return jsonb_build_object('kind','unavailable'); end if;
  select * into m from player.group_members where session_id=s.id and actor_id=p_actor;
  if m.session_id is null then return jsonb_build_object('kind','unavailable'); end if;
  if m.left_at is null then
    update player.group_members set left_at=now()
      where session_id=s.id and actor_id=p_actor;
    if s.status in ('forming','in_progress') then
      update player.group_sessions set status='abandoned',
        invite_hash=null,invite_expires_at=null,updated_at=now()
      where id=s.id;
    end if;
  end if;
  return jsonb_build_object('kind','left');
end $fn$;

-- PostgreSQL gives EXECUTE to PUBLIC on new functions unless explicitly
-- revoked. No browser-facing roles may call any privileged group RPC.
revoke all on function public.sideworld_group_create_v1(
  uuid,uuid,text,uuid,jsonb,text,timestamptz) from public,anon,authenticated;
revoke all on function public.sideworld_group_join_v1(
  uuid,uuid,text) from public,anon,authenticated;
revoke all on function public.sideworld_group_get_v1(
  uuid,uuid) from public,anon,authenticated;
revoke all on function public.sideworld_group_receipt_get_v1(
  uuid,uuid,uuid) from public,anon,authenticated;
revoke all on function public.sideworld_group_apply_v1(
  uuid,uuid,uuid,text,integer,jsonb,boolean) from public,anon,authenticated;
revoke all on function public.sideworld_group_leave_v1(
  uuid,uuid) from public,anon,authenticated;

grant execute on function public.sideworld_group_create_v1(
  uuid,uuid,text,uuid,jsonb,text,timestamptz) to service_role;
grant execute on function public.sideworld_group_join_v1(
  uuid,uuid,text) to service_role;
grant execute on function public.sideworld_group_get_v1(
  uuid,uuid) to service_role;
grant execute on function public.sideworld_group_receipt_get_v1(
  uuid,uuid,uuid) to service_role;
grant execute on function public.sideworld_group_apply_v1(
  uuid,uuid,uuid,text,integer,jsonb,boolean) to service_role;
grant execute on function public.sideworld_group_leave_v1(
  uuid,uuid) to service_role;

commit;

-- Required staging verification BEFORE converting this draft to migration:
-- * fresh anonymous/authenticated account cannot invoke group RPCs;
-- * member/actor IDOR + roles, invite replay/expiration, duplicate joins;
-- * revocation between Next.js authorization and locked DB CAS;
-- * concurrent join and concurrent apply from two separate transactions;
-- * same request_id with different fingerprint AND a different actor;
-- * terminal transition idempotency and post-completion read;
-- * roleClues never returned in any JSON response or log;
-- * injected JWT claims/user_metadata cannot grant access;
-- * all returned private progress stays exclusively on trusted server;
-- * Sql advisors and backup/restore confirmed; feature flags remain OFF.
