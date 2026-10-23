-- SIDEWORLD cooperative group persistence — REVIEW DRAFT ONLY.
-- NOT an executable Supabase migration and NOT deployed to any environment.
-- Copy into a Supabase CLI-created migration only after explicit production DDL
-- authorization, verified backup/restore, dependency audit, and isolated tests.
-- Current baseline: production schema queried read-only 2026-10-23.
--
-- New tables DO NOT alter canonical universes, existing player.quest_runs,
-- canon.quest_releases or the existing single-player RPCs.
--
-- IMPORTANT: Transactional group RPC implementations and verified actor
-- identity must be reviewed together with this schema before activation.

begin;

create table player.group_sessions (
  id uuid primary key default gen_random_uuid(),
  release_id uuid not null references canon.quest_releases(id) on delete restrict,
  host_actor_id uuid not null references auth.users(id) on delete restrict,
  start_request_id uuid not null,
  mode text not null check (mode in ('couple','team')),
  status text not null default 'forming'
    check (status in ('forming','in_progress','completed','abandoned')),
  expected_players smallint not null check (
    (mode='couple' and expected_players=2) or
    (mode='team' and expected_players in (3,4))
  ),
  access_mode text not null
    check (access_mode in ('private','private_qa','published')),
  engine_version integer not null default 1 check (engine_version=1),
  engine_content_hash text not null
    check (engine_content_hash ~ '^[0-9a-f]{64}$'),
  progress jsonb not null,
  sequence integer not null default 0
    check (sequence between 0 and 10000),
  -- Store SHA-256 of a server-minted 32-byte invitation secret, not the secret.
  -- The HTTP route must use an authenticated identity and strict rate limits.
  invite_hash text check (invite_hash ~ '^[0-9a-f]{64}$'),
  invite_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),

  constraint group_session_start_unique
    unique (host_actor_id,release_id,start_request_id),
  constraint group_session_progress_shape check (
    case when jsonb_typeof(progress)='object'
           and jsonb_typeof(progress->'events')='array'
      then pg_column_size(progress)<=262144
        and progress->'engineVersion'='1'::jsonb
        and progress->>'contentHash'=engine_content_hash
        and progress->'sequence'=to_jsonb(sequence)
        and jsonb_array_length(progress->'events')=sequence
      else false end
  ),
  constraint group_session_invite_lifecycle check (
    (status='forming' and invite_hash is not null
      and invite_expires_at is not null)
    or (status<>'forming' and invite_hash is null
      and invite_expires_at is null)
  )
);

-- Single actor can occupy at most one role in a session; V1 does not allow
-- rejoining after leaving. Host leaves -> abandoned, not owner transfer.
create table player.group_members (
  session_id uuid not null references player.group_sessions(id) on delete restrict,
  actor_id uuid not null references auth.users(id) on delete restrict,
  role_id text not null check (role_id ~ '^[a-z][a-z0-9_-]{0,39}$'),
  joined_at timestamptz not null default now(),
  left_at timestamptz,
  primary key (session_id,actor_id),
  constraint group_members_left_after_join
    check (left_at is null or left_at>=joined_at)
);

create unique index group_members_one_active_role
  on player.group_members(session_id,role_id)
  where left_at is null;

create index group_members_actor_lookup
  on player.group_members(actor_id,session_id)
  where left_at is null;

create index group_sessions_host_recent
  on player.group_sessions(host_actor_id, created_at desc);

-- A request ID is scoped to exactly one actor in exactly one group;
-- a differently fingerprinted replay must conflict, including post-completion.
create table player.group_receipts (
  session_id uuid not null,
  request_id uuid not null,
  actor_id uuid not null,
  fingerprint text not null check (fingerprint ~ '^[0-9a-f]{64}$'),
  result_sequence integer not null
    check (result_sequence between 1 and 10000),
  result_status text not null check (result_status in ('in_progress','completed')),
  created_at timestamptz not null default now(),
  primary key (session_id,request_id),
  foreign key (session_id,actor_id)
    references player.group_members(session_id,actor_id)
    on delete restrict
);

create index group_receipts_actor_lookup
  on player.group_receipts(actor_id,session_id,created_at desc);

-- Deliberately NO RLS policies. Only a service-role-only, audited,
-- actor-scoped SECURITY DEFINER RPC may touch the tables; no browser
-- should ever be able to fetch group progress or raw member records.
alter table player.group_sessions enable row level security;
alter table player.group_members enable row level security;
alter table player.group_receipts enable row level security;

revoke all privileges on player.group_sessions,
  player.group_members,player.group_receipts
  from public,anon,authenticated,service_role;

comment on table player.group_sessions is
  'Private SIDEWORLD shared quest progress. Server RPC only; never expose via client Data API.';
comment on table player.group_members is
  'Private, actor-scoped SIDEWORLD cooperative membership and role. No direct client access.';
comment on table player.group_receipts is
  'Private idempotency record; must commit in same transaction as group progress.';

commit;

-- Deployment blockers:
-- [ ] Supabase CLI migration new <name> creates the REAL migration filename.
-- [ ] SQL syntax, constraints and indexes exercised on isolated staging.
-- [ ] RPC access: PUBLIC/anon/authenticated denied; service_role only.
-- [ ] RLS advisor reviewed; verified encrypted backup plus restore rehearsal.
-- [ ] Member revocation, duplicate joins, CAS race, terminal retry, invite expiry.
-- [ ] Explicit founder approval for production DDL (not granted by this draft).
