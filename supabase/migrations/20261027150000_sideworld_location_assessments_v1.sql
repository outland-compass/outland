-- SIDEWORLD AI Location Assessments V1 — PROPOSED, NOT AUTHORIZED FOR PRODUCTION.
-- Additive only. Reuses canonical geo.locations and canon.franchises.
-- Scores are an editorial AI hypothesis: never field verification, public
-- access permission, a playable quest, or an approved release.
-- Do not apply until the founder explicitly approves the migration and
-- production backup + tested restore readiness are confirmed.
--
-- Runtime model: Studio server-only service_role RPC, owner actor checked
-- inside the SECURITY DEFINER write function, no browser table access.

create table geo.location_assessments (
  id uuid primary key default gen_random_uuid(),
  location_id uuid not null references geo.locations(id) on delete restrict,
  franchise_id uuid not null references canon.franchises(id) on delete restrict,
  canon_version integer not null check (canon_version > 0),
  model_version text not null check (length(btrim(model_version)) between 3 and 120),
  rubric_version text not null check (rubric_version = 'sideworld.location-scoring.v1'),
  input_fingerprint text not null check (input_fingerprint ~ '^[0-9a-f]{64}$'),
  dimensions jsonb not null check (jsonb_typeof(dimensions) = 'object'),
  score_100 smallint not null check (score_100 between 0 and 100),
  confidence numeric(5,4) not null check (confidence between 0 and 1),
  risk_flags jsonb not null default '[]'::jsonb check (jsonb_typeof(risk_flags) = 'array'),
  puzzle_opportunities jsonb not null default '[]'::jsonb check (jsonb_typeof(puzzle_opportunities) = 'array'),
  draft_eligible boolean not null default false,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint geo_location_assessments_unique
    unique (location_id,franchise_id,canon_version,model_version,rubric_version,input_fingerprint)
);

create index geo_location_assessments_lookup_idx on
  geo.location_assessments(franchise_id,location_id,created_at desc);

comment on table geo.location_assessments is
  'Private, versioned AI editorial scores for canonical locations per franchise. No location verification, field QA or publication claim.';

alter table geo.location_assessments enable row level security;
revoke all on geo.location_assessments from public, anon, authenticated, service_role;
-- No direct table privileges for client JWTs or service_role. Only
-- allowlisted SECURITY DEFINER RPCs below are executable by service_role.

create function public.sideworld_location_assessment_record_v1(
  p_actor uuid,
  p_location_id uuid,
  p_franchise_id uuid,
  p_canon_version integer,
  p_model_version text,
  p_rubric_version text,
  p_input_fingerprint text,
  p_dimensions jsonb,
  p_confidence numeric,
  p_risk_flags jsonb,
  p_puzzle_opportunities jsonb,
  p_draft_eligible boolean
) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  v_canon_version integer;
  v_key text;
  v_value integer;
  v_score integer := 0;
  v_id uuid;
  v_access boolean;
begin
  if p_actor is null or not exists (
    select 1 from shared.user_roles ur
    where ur.user_id = p_actor and ur.role::text in ('OWNER','ADMIN')
  ) then raise exception 'Admin role required'; end if;

  select f.canon_version into v_canon_version
    from canon.franchises f
    where f.id = p_franchise_id and f.status <> 'archived';
  if v_canon_version is null or v_canon_version is distinct from p_canon_version
    then raise exception 'Franchise canon version changed'; end if;
  select l.public_access into v_access from geo.locations l where l.id=p_location_id;
  if not found then raise exception 'Location missing'; end if;

  if p_model_version is null or length(btrim(p_model_version)) not between 3 and 120
    or p_rubric_version is distinct from 'sideworld.location-scoring.v1'
    or p_input_fingerprint !~ '^[0-9a-f]{64}$'
    then raise exception 'Invalid rubric, model or input fingerprint'; end if;
  if p_dimensions is null or jsonb_typeof(p_dimensions) is distinct from 'object'
    then raise exception 'Invalid dimension object'; end if;
  if p_confidence is null or p_confidence not between 0 and 1
    then raise exception 'Invalid confidence'; end if;
  if p_draft_eligible is null or p_risk_flags is null or
     jsonb_typeof(p_risk_flags) is distinct from 'array' or
     p_puzzle_opportunities is null or
     jsonb_typeof(p_puzzle_opportunities) is distinct from 'array' or
     jsonb_array_length(p_puzzle_opportunities)>5
    then raise exception 'Invalid scoring review metadata'; end if;
  if exists (
    select 1 from jsonb_array_elements_text(p_risk_flags) AS flag
    where flag not in ('access_unknown','restricted_access','unsafe_access',
      'sensitive_site','physical_clue_unconfirmed','coordinates_unconfirmed',
      'hours_unknown','field_qa_pending','needs_research')
  ) then raise exception 'Unrecognized safety flag'; end if;
  if (v_access is false or p_risk_flags ? 'unsafe_access'
      or p_risk_flags ? 'restricted_access') and p_draft_eligible
    then raise exception 'Known unsafe or restricted access cannot be route eligible'; end if;

  foreach v_key in array array[
    'storyStrength','physicalEvidence','puzzlePotential','franchiseFit','operationalReadiness'
  ] loop
    if jsonb_typeof(p_dimensions -> v_key) is distinct from 'object' or
       jsonb_typeof(p_dimensions -> v_key -> 'score') is distinct from 'number' or
       jsonb_typeof(p_dimensions -> v_key -> 'sourceIds') is distinct from 'array' or
       length(btrim(coalesce(p_dimensions -> v_key ->> 'rationale',''))) < 8
      then raise exception 'Invalid AI dimension: %',v_key; end if;
    v_value := (p_dimensions -> v_key ->> 'score')::integer;
    if v_value not between 0 and 5
      then raise exception 'Dimension outside the 0–5 rubric: %',v_key; end if;
    v_score:=v_score + v_value*(case v_key
      when 'storyStrength' then 5 when 'physicalEvidence' then 5
      when 'puzzlePotential' then 5 when 'franchiseFit' then 3
      else 2 end);
  end loop;
  if v_score not between 0 and 100 then raise exception 'Invalid composite score'; end if;

  -- Immutable results. Replaying the same input+model+rubric uses the original
  -- assessment; the AI model may not overwrite its previous scored reasoning.
  insert into geo.location_assessments(
    location_id,franchise_id,canon_version,model_version,rubric_version,
    input_fingerprint,dimensions,score_100,confidence,risk_flags,
    puzzle_opportunities,draft_eligible,created_by
  ) values (
    p_location_id,p_franchise_id,p_canon_version,p_model_version,p_rubric_version,
    p_input_fingerprint,p_dimensions,v_score,p_confidence,p_risk_flags,
    p_puzzle_opportunities,p_draft_eligible,p_actor
  )
  on conflict on constraint geo_location_assessments_unique do nothing
  returning id into v_id;
  if v_id is null then
    select a.id into v_id from geo.location_assessments a
    where a.location_id=p_location_id and a.franchise_id=p_franchise_id and
      a.canon_version=p_canon_version and a.model_version=p_model_version and
      a.rubric_version=p_rubric_version and a.input_fingerprint=p_input_fingerprint;
  end if;
  if v_id is null then raise exception 'Assessment storage did not complete'; end if;
  return v_id;
end;
$$;

create function public.sideworld_location_assessments_for_city_v1(
  p_city_id uuid, p_franchise_id uuid, p_model_version text,
  p_rubric_version text
) returns jsonb
language sql stable security definer set search_path = ''
as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'locationId', a.location_id,
    'cityId',l.city_id,
    'franchiseId',a.franchise_id,
    'fingerprint',a.input_fingerprint,
    'rubricVersion',a.rubric_version,
    'modelVersion',a.model_version,
    'dimensions',a.dimensions,
    'score',a.score_100,
    'band', case when a.score_100>=85 then 'S'
      when a.score_100>=70 then 'A'
      when a.score_100>=50 then 'B' else 'C' end,
    'confidence',a.confidence,
    'riskFlags',a.risk_flags,
    'puzzleOpportunities',a.puzzle_opportunities,
    'draftEligible',a.draft_eligible,
    'publicationApproved',false
  ) order by a.score_100 desc,a.location_id),'[]'::jsonb)
  from (
    select distinct on (a.location_id) a.*
    from geo.location_assessments a
    join geo.locations l on l.id=a.location_id
    where l.city_id=p_city_id and a.franchise_id=p_franchise_id and
      a.model_version=p_model_version and a.rubric_version=p_rubric_version
    order by a.location_id,a.created_at desc,a.id desc
    limit 500
  ) a
  join geo.locations l on l.id=a.location_id;
$$;

revoke all on function public.sideworld_location_assessment_record_v1(
  uuid,uuid,uuid,integer,text,text,text,jsonb,numeric,jsonb,jsonb,boolean
) from public,anon,authenticated,service_role;
revoke all on function public.sideworld_location_assessments_for_city_v1(
  uuid,uuid,text,text
) from public,anon,authenticated,service_role;
grant execute on function public.sideworld_location_assessment_record_v1(
  uuid,uuid,uuid,integer,text,text,text,jsonb,numeric,jsonb,jsonb,boolean
) to service_role;
grant execute on function public.sideworld_location_assessments_for_city_v1(
  uuid,uuid,text,text
) to service_role;
