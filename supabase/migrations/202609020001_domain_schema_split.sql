-- 202609020001_domain_schema_split.sql
-- OUTLAND PR1: database namespace refactor.
-- Splits the flat `public` schema into two domain schemas:
--   shared = cross-OUTLAND entities (profiles, user_roles, worlds, assets, activities)
--   land   = COMPASS / property intelligence entities (Radar, evaluations, DD, evidence, ...)
--
-- This migration only moves existing objects between schemas (ALTER ... SET SCHEMA) and
-- repoints the bodies of the `public` helper/workflow functions and audit trigger that must
-- stay in `public` for API compatibility. It does not create, drop, or redesign any table,
-- column, index, trigger, RLS policy, or piece of data. Enums/types remain in `public`.

begin;

create schema if not exists shared;
create schema if not exists land;

grant usage on schema shared to anon, authenticated, service_role;
grant usage on schema land to anon, authenticated, service_role;

-- Mirror the exposure model used for `public` so future objects created in the new domain
-- schemas keep working with the Data API without manual grants.
alter default privileges in schema shared grant select, insert, update, delete on tables to anon, authenticated, service_role;
alter default privileges in schema shared grant usage, select on sequences to anon, authenticated, service_role;
alter default privileges in schema land grant select, insert, update, delete on tables to anon, authenticated, service_role;
alter default privileges in schema land grant usage, select on sequences to anon, authenticated, service_role;

-- 1. Cross-OUTLAND entities -> `shared`.
-- ALTER TABLE ... SET SCHEMA preserves data, PK/FK constraints, indexes, triggers, RLS
-- policies, table/sequence grants, and identity ownership; only the namespace changes.
alter table public.profiles set schema shared;
alter table public.user_roles set schema shared;
alter table public.worlds set schema shared;
alter table public.assets set schema shared;
alter table public.activities set schema shared;

-- 2. COMPASS / property intelligence entities -> `land`.
alter table public.score_dimensions set schema land;
alter table public.world_dimension_weights set schema land;
alter table public.world_score_criteria set schema land;
alter table public.world_gate_definitions set schema land;
alter table public.signals set schema land;
alter table public.candidates set schema land;
alter table public.candidate_sources set schema land;
alter table public.candidate_price_history set schema land;
alter table public.candidate_media set schema land;
alter table public.candidate_economics set schema land;
alter table public.evaluations set schema land;
alter table public.evaluation_dimension_weights set schema land;
alter table public.evaluation_items set schema land;
alter table public.candidate_gates set schema land;
alter table public.dd_items set schema land;
alter table public.documents set schema land;
alter table public.evidence_items set schema land;
alter table public.notes set schema land;
alter table public.visits set schema land;
alter table public.decisions set schema land;

-- 3. COMPASS read-model views -> `land`. View definitions resolve their underlying tables by
-- OID, not by schema-qualified name, so moving the view namespace does not require rewriting
-- the query text.
alter view public.v_evaluation_dimension_scores set schema land;
alter view public.v_evaluation_scores set schema land;
alter view public.v_candidate_gate_summary set schema land;
alter view public.v_candidate_latest_evaluation set schema land;
alter view public.v_candidate_radar set schema land;

-- 4. Re-point auth/profile helper functions (kept in `public` for API compatibility) at
-- `shared`. CREATE OR REPLACE FUNCTION keeps the existing object (and its grants/ACLs); only
-- the body text changes.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into shared.profiles (id, display_name, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'display_name', new.raw_user_meta_data ->> 'full_name'),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.has_app_role(allowed public.app_role[])
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from shared.user_roles ur
    where ur.user_id = (select auth.uid())
      and ur.role = any(allowed)
  );
$$;

-- 5. Re-point COMPASS workflow RPCs (kept in `public` for API compatibility) at `land`.
create or replace function public.start_evaluation(p_candidate_id uuid)
returns uuid
language plpgsql
set search_path = public
as $$
declare
  v_world_id uuid;
  v_eval_id uuid;
  v_version integer;
begin
  if not public.can_analyze() then
    raise exception 'Not authorized';
  end if;

  select world_id into v_world_id
  from land.candidates
  where id = p_candidate_id;

  if v_world_id is null then
    raise exception 'Candidate not found';
  end if;

  select coalesce(max(version_no), 0) + 1
    into v_version
  from land.evaluations
  where candidate_id = p_candidate_id;

  insert into land.evaluations(candidate_id, world_id, version_no, created_by)
  values (p_candidate_id, v_world_id, v_version, auth.uid())
  returning id into v_eval_id;

  insert into land.evaluation_dimension_weights(evaluation_id, dimension, weight)
  select v_eval_id, dimension, weight
  from land.world_dimension_weights
  where world_id = v_world_id;

  insert into land.evaluation_items(
    evaluation_id, source_criterion_id, dimension, criterion_code, criterion_label,
    item_weight, is_required, updated_by
  )
  select
    v_eval_id, id, dimension, code, label,
    item_weight, is_required, auth.uid()
  from land.world_score_criteria
  where world_id = v_world_id and is_active = true
  order by dimension, sort_order, label;

  return v_eval_id;
end;
$$;

create or replace function public.initialize_candidate_gates(p_candidate_id uuid)
returns integer
language plpgsql
set search_path = public
as $$
declare
  v_world_id uuid;
  v_inserted integer;
begin
  if not public.can_analyze() then
    raise exception 'Not authorized';
  end if;

  select world_id into v_world_id
  from land.candidates
  where id = p_candidate_id;

  if v_world_id is null then
    raise exception 'Candidate not found';
  end if;

  insert into land.candidate_gates(
    candidate_id, source_definition_id, gate_code, category, gate_label,
    is_critical, updated_by
  )
  select
    p_candidate_id, id, code, category, label,
    is_critical, auth.uid()
  from land.world_gate_definitions
  where world_id = v_world_id and is_active = true
  on conflict (candidate_id, gate_code) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

create or replace function public.promote_signal_to_candidate(
  p_signal_id uuid,
  p_world_id uuid,
  p_title text default null
)
returns uuid
language plpgsql
set search_path = public
as $$
declare
  s land.signals%rowtype;
  v_candidate_id uuid;
  v_source_id uuid;
begin
  if not public.can_analyze() then
    raise exception 'Not authorized';
  end if;

  select * into s
  from land.signals
  where id = p_signal_id
  for update;

  if not found then
    raise exception 'Signal not found';
  end if;

  if s.promoted_candidate_id is not null then
    return s.promoted_candidate_id;
  end if;

  insert into land.candidates(
    world_id, title, asset_kind,
    asking_price, currency, area_m2,
    description, date_discovered, last_seen_at,
    created_by
  )
  values (
    p_world_id,
    coalesce(p_title, s.raw_title, 'Untitled candidate'),
    case
      when (s.extracted_payload ->> 'asset_kind') in ('LAND','BUILDING','FLOATING','MOBILE','OTHER')
        then (s.extracted_payload ->> 'asset_kind')::public.asset_kind
      else 'LAND'::public.asset_kind
    end,
    s.raw_price,
    coalesce(s.raw_currency, 'EUR'),
    s.raw_area_m2,
    s.raw_description,
    s.discovered_at::date,
    s.last_seen_at,
    auth.uid()
  )
  returning id into v_candidate_id;

  insert into land.candidate_sources(
    candidate_id, signal_id, source_name, source_url, source_listing_id,
    first_seen_at, last_seen_at, source_snapshot
  )
  values (
    v_candidate_id, s.id, coalesce(s.source_name,'Unknown source'), s.source_url,
    s.source_listing_id, s.discovered_at, s.last_seen_at,
    jsonb_build_object(
      'raw_payload', s.raw_payload,
      'extracted_payload', s.extracted_payload
    )
  )
  returning id into v_source_id;

  if s.raw_price is not null then
    insert into land.candidate_price_history(candidate_id, source_id, observed_at, price, currency, note)
    values (v_candidate_id, v_source_id, s.discovered_at, s.raw_price, coalesce(s.raw_currency,'EUR'), 'Initial signal price');
  end if;

  update land.signals
     set status = 'PROMOTED',
         world_id = p_world_id,
         promoted_candidate_id = v_candidate_id,
         updated_at = now()
   where id = p_signal_id;

  perform public.initialize_candidate_gates(v_candidate_id);

  return v_candidate_id;
end;
$$;

-- 6. Re-point the audit trigger (kept in `public`) at `shared.activities`.
create or replace function public.audit_compass_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate_id uuid;
  v_entity_id text;
begin
  v_entity_id := coalesce(
    case when tg_op <> 'DELETE' then to_jsonb(new)->>'id' end,
    case when tg_op <> 'INSERT' then to_jsonb(old)->>'id' end
  );

  v_candidate_id := coalesce(
    case when tg_op <> 'DELETE' then nullif(to_jsonb(new)->>'candidate_id','')::uuid end,
    case when tg_op <> 'INSERT' then nullif(to_jsonb(old)->>'candidate_id','')::uuid end,
    case when tg_table_name = 'candidates' and tg_op <> 'DELETE' then new.id else null end,
    case when tg_table_name = 'candidates' and tg_op <> 'INSERT' then old.id else null end
  );

  insert into shared.activities(
    candidate_id, entity_type, entity_id, action, actor_id, old_data, new_data
  )
  values (
    v_candidate_id,
    tg_table_name,
    v_entity_id,
    tg_op,
    auth.uid(),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

commit;
