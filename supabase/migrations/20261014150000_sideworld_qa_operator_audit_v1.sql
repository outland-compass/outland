-- SIDEWORLD QA operator durable audit V1.
-- ADDITIVE proposal only: NEVER run against production without a separate approval.
-- Requires applied 20261014104136_sideworld_player_runtime_v1 exactly once.
-- Source review: canon.quest_releases/player.qa_access and the three service-only
-- public.sideworld_player_qa_*_v1 RPCs. No universe duplication, no backfills.
-- Atomic trigger writes record metadata ONLY, never authored answers or JWTs.

alter table player.qa_access
  add column revoked_by uuid references auth.users(id) on delete restrict;

create table player.qa_operator_audit (
  id bigint generated always as identity primary key,
  event_type text not null check (event_type in (
    'release_created','access_granted','access_extended',
    'access_reenabled','access_revoked'
  )),
  operator_id uuid,
  release_id uuid not null,
  tester_id uuid,
  occurred_at timestamptz not null default now(),
  check ((event_type='release_created' and tester_id is null)
      or (event_type<>'release_created' and tester_id is not null))
);
create index qa_operator_audit_release_idx
  on player.qa_operator_audit(release_id,occurred_at desc);
comment on table player.qa_operator_audit is
  'Append-only metadata-only audit of private QA release creation and tester access lifecycle. Never stores answer keys or tokens. NULL operator only for legacy/direct revocations.';

alter table player.qa_operator_audit enable row level security;
revoke all on player.qa_operator_audit from public,anon,authenticated,service_role;
revoke all on sequence player.qa_operator_audit_id_seq from public,anon,authenticated,service_role;

create function player.guard_qa_audit_v1()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  raise exception 'QA operator audit history cannot be changed';
end $$;
create trigger qa_operator_audit_immutable_v1
before update or delete on player.qa_operator_audit
for each row execute function player.guard_qa_audit_v1();
revoke all on function player.guard_qa_audit_v1()
  from public,anon,authenticated,service_role;

create function player.capture_qa_operator_audit_v1()
returns trigger language plpgsql security definer set search_path='' as $$
declare event_name text;
        operator_uuid uuid;
begin
  if TG_TABLE_SCHEMA='canon' and TG_TABLE_NAME='quest_releases' then
    if TG_OP <> 'INSERT' then raise exception 'Unexpected QA release audit operation'; end if;
    -- Publication follows a separate workflow; this is private-QA creation metadata only.
    if new.visibility='private_qa' then
      insert into player.qa_operator_audit(event_type,operator_id,release_id)
      values('release_created',new.created_by,new.id);
    end if;
    return new;
  end if;
  if TG_TABLE_SCHEMA<>'player' or TG_TABLE_NAME<>'qa_access' then
    raise exception 'Unexpected QA access audit table';
  end if;
  if TG_OP='INSERT' then
    event_name:='access_granted';
    operator_uuid:=new.granted_by;
  elsif TG_OP='UPDATE' then
    if old.revoked_at is null and new.revoked_at is not null then
      event_name:='access_revoked';
      -- Existing direct SQL revocations may have no human attribution.
      operator_uuid:=new.revoked_by;
    elsif old.revoked_at is not null and new.revoked_at is null then
      event_name:='access_reenabled';
      operator_uuid:=new.granted_by;
    elsif old.expires_at is distinct from new.expires_at or
          old.granted_by is distinct from new.granted_by then
      event_name:='access_extended';
      operator_uuid:=new.granted_by;
    else
      return new;
    end if;
  else
    raise exception 'Unexpected QA access audit operation';
  end if;
  insert into player.qa_operator_audit(event_type,operator_id,release_id,tester_id)
  values(event_name,operator_uuid,new.release_id,new.actor_id);
  return new;
end $$;
revoke all on function player.capture_qa_operator_audit_v1()
  from public,anon,authenticated,service_role;

create trigger qa_release_audit_v1
after insert on canon.quest_releases
for each row execute function player.capture_qa_operator_audit_v1();
create trigger qa_access_audit_v1
after insert or update on player.qa_access
for each row execute function player.capture_qa_operator_audit_v1();

-- Preserve the original function signatures and service-only EXECUTE contract.
-- Successful grants/regrants clear stale revocation attribution atomically.
create or replace function public.sideworld_player_qa_grant_v1(
  p_operator uuid,p_release_id uuid,p_tester_id uuid,p_expires_at timestamptz
) returns jsonb language plpgsql security definer set search_path='' as $$
begin
  if p_release_id is null or p_tester_id is null or p_expires_at is null or
     p_expires_at<=now()+interval '5 minutes' or
     p_expires_at>now()+interval '14 days' then
    return jsonb_build_object('kind','invalid');
  end if;
  if not player.is_qa_operator_v1(p_operator) then
    return jsonb_build_object('kind','unavailable');
  end if;
  if not exists(select 1 from canon.quest_releases
                where id=p_release_id and visibility='private_qa')
     or not exists(select 1 from auth.users where id=p_tester_id) then
    return jsonb_build_object('kind','unavailable');
  end if;
  insert into player.qa_access(release_id,actor_id,expires_at,granted_by)
  values(p_release_id,p_tester_id,p_expires_at,p_operator)
  on conflict(release_id,actor_id) do update
     set expires_at=excluded.expires_at,revoked_at=null,revoked_by=null,
         granted_by=excluded.granted_by;
  return jsonb_build_object('kind','granted','releaseId',p_release_id,
                            'testerId',p_tester_id,'expiresAt',p_expires_at);
end $$;

create or replace function public.sideworld_player_qa_revoke_v1(
  p_operator uuid,p_release_id uuid,p_tester_id uuid
) returns jsonb language plpgsql security definer set search_path='' as $$
declare access_row player.qa_access;
begin
  if p_release_id is null or p_tester_id is null then
    return jsonb_build_object('kind','invalid');
  end if;
  if not player.is_qa_operator_v1(p_operator) then
    return jsonb_build_object('kind','unavailable');
  end if;
  update player.qa_access
  set revoked_at=coalesce(revoked_at,now()),
      revoked_by=case when revoked_at is null then p_operator else revoked_by end
  where release_id=p_release_id and actor_id=p_tester_id returning * into access_row;
  if access_row.release_id is null then
    return jsonb_build_object('kind','unavailable');
  end if;
  return jsonb_build_object('kind','revoked','releaseId',p_release_id,
                            'testerId',p_tester_id);
end $$;

revoke all on function public.sideworld_player_qa_grant_v1(uuid,uuid,uuid,timestamptz),
  public.sideworld_player_qa_revoke_v1(uuid,uuid,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.sideworld_player_qa_grant_v1(uuid,uuid,uuid,timestamptz),
  public.sideworld_player_qa_revoke_v1(uuid,uuid,uuid)
  to service_role;

-- Rollback plan (manual, separately reviewed):
-- 1. Disable QA write flag; revoke live grants before any change.
-- 2. Roll back the two RPC bodies to 20261014104136 definitions.
-- 3. Drop qa_release_audit_v1 and qa_access_audit_v1 triggers only.
-- 4. KEEP qa_operator_audit and revoked_by to preserve evidence.
-- NO automatic drops, deletes or data migration.
