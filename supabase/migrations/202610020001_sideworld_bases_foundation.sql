-- Additive SIDEWORLD accommodation schema. Do not deploy before isolated replay.
create schema if not exists infrastructure;

create table infrastructure.bases (
 id uuid primary key default gen_random_uuid(),
 world_id uuid not null references shared.worlds(id),
 asset_id uuid references shared.assets(id),
 name text not null check (length(trim(name)) > 0),
 status text not null default 'planned' check (status in ('planned','active','retired')),
 guest_capacity integer check (guest_capacity > 0),
 metadata jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);

alter table infrastructure.bases enable row level security;
revoke all on schema infrastructure from public, anon, authenticated;
revoke all on infrastructure.bases from public, anon, authenticated;
