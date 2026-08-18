-- 202608180001_core_auth.sql
-- OUTLAND COMPASS v0.1 / M2
-- Core enums, profiles, roles and common functions.

create extension if not exists pgcrypto;

do $$ begin
  create type public.app_role as enum ('OWNER','ADMIN','ANALYST','ADVISOR','VIEWER');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.asset_kind as enum ('LAND','BUILDING','FLOATING','MOBILE','OTHER');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.candidate_status as enum
    ('NEW','REVIEWED','SHORTLIST','DD','NEGOTIATION','ACQUIRED','REJECTED','ARCHIVED','SOLD');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.signal_status as enum ('NEW','REVIEWED','PROMOTED','DISMISSED','STALE');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.listing_status as enum ('ACTIVE','REMOVED','SOLD','EXPIRED','UNKNOWN');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.score_dimension as enum ('PLACE','FEASIBILITY','ECONOMICS','OUTLAND','NETWORK');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.evidence_state as enum ('UNKNOWN','CLAIMED','OBSERVED','VERIFIED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.gate_state as enum ('UNKNOWN','PASS','FAIL','NOT_APPLICABLE');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.dd_status as enum ('OPEN','IN_PROGRESS','VERIFIED','FAILED','NOT_APPLICABLE');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.dd_severity as enum ('INFO','IMPORTANT','GATE');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.verification_state as enum ('UNVERIFIED','PARTIALLY_VERIFIED','VERIFIED','DISPUTED');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.evidence_type as enum
    ('SELLER_STATEMENT','LISTING','DOCUMENT','REGISTRY','PROFESSIONAL_OPINION','PHOTO','SITE_VISIT','MAP','EXTERNAL_URL','OTHER');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.decision_type as enum
    ('REVIEW','SHORTLIST','START_DD','NEGOTIATE','REJECT','ARCHIVE','ACQUIRE','REOPEN');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.evaluation_status as enum ('DRAFT','FINAL');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role public.app_role not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id),
  primary key (user_id, role)
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'full_name'),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

create or replace function public.has_app_role(allowed public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role = any(allowed)
  );
$$;

create or replace function public.can_read()
returns boolean language sql stable
as $$ select public.has_app_role(array['OWNER','ADMIN','ANALYST','ADVISOR','VIEWER']::public.app_role[]); $$;

create or replace function public.can_analyze()
returns boolean language sql stable
as $$ select public.has_app_role(array['OWNER','ADMIN','ANALYST']::public.app_role[]); $$;

create or replace function public.can_contribute_evidence()
returns boolean language sql stable
as $$ select public.has_app_role(array['OWNER','ADMIN','ANALYST','ADVISOR']::public.app_role[]); $$;

create or replace function public.can_admin()
returns boolean language sql stable
as $$ select public.has_app_role(array['OWNER','ADMIN']::public.app_role[]); $$;

revoke all on function public.has_app_role(public.app_role[]) from anon;
revoke all on function public.can_read() from anon;
revoke all on function public.can_analyze() from anon;
revoke all on function public.can_contribute_evidence() from anon;
revoke all on function public.can_admin() from anon;

grant execute on function public.has_app_role(public.app_role[]) to authenticated;
grant execute on function public.can_read() to authenticated;
grant execute on function public.can_analyze() to authenticated;
grant execute on function public.can_contribute_evidence() to authenticated;
grant execute on function public.can_admin() to authenticated;

create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();
