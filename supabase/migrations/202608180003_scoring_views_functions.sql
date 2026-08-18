-- 202608180003_scoring_views_functions.sql
-- OUTLAND COMPASS v0.1 / M2
-- Versioned evaluations, scoring, gates, Radar read model and promotion RPCs.

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
  from public.candidates
  where id = p_candidate_id;

  if v_world_id is null then
    raise exception 'Candidate not found';
  end if;

  select coalesce(max(version_no), 0) + 1
    into v_version
  from public.evaluations
  where candidate_id = p_candidate_id;

  insert into public.evaluations(candidate_id, world_id, version_no, created_by)
  values (p_candidate_id, v_world_id, v_version, auth.uid())
  returning id into v_eval_id;

  insert into public.evaluation_dimension_weights(evaluation_id, dimension, weight)
  select v_eval_id, dimension, weight
  from public.world_dimension_weights
  where world_id = v_world_id;

  insert into public.evaluation_items(
    evaluation_id, source_criterion_id, dimension, criterion_code, criterion_label,
    item_weight, is_required, updated_by
  )
  select
    v_eval_id, id, dimension, code, label,
    item_weight, is_required, auth.uid()
  from public.world_score_criteria
  where world_id = v_world_id and is_active = true
  order by dimension, sort_order, label;

  return v_eval_id;
end;
$$;

grant execute on function public.start_evaluation(uuid) to authenticated;

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
  from public.candidates
  where id = p_candidate_id;

  if v_world_id is null then
    raise exception 'Candidate not found';
  end if;

  insert into public.candidate_gates(
    candidate_id, source_definition_id, gate_code, category, gate_label,
    is_critical, updated_by
  )
  select
    p_candidate_id, id, code, category, label,
    is_critical, auth.uid()
  from public.world_gate_definitions
  where world_id = v_world_id and is_active = true
  on conflict (candidate_id, gate_code) do nothing;

  get diagnostics v_inserted = row_count;
  return v_inserted;
end;
$$;

grant execute on function public.initialize_candidate_gates(uuid) to authenticated;

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
  s public.signals%rowtype;
  v_candidate_id uuid;
  v_source_id uuid;
begin
  if not public.can_analyze() then
    raise exception 'Not authorized';
  end if;

  select * into s
  from public.signals
  where id = p_signal_id
  for update;

  if not found then
    raise exception 'Signal not found';
  end if;

  if s.promoted_candidate_id is not null then
    return s.promoted_candidate_id;
  end if;

  insert into public.candidates(
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

  insert into public.candidate_sources(
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
    insert into public.candidate_price_history(candidate_id, source_id, observed_at, price, currency, note)
    values (v_candidate_id, v_source_id, s.discovered_at, s.raw_price, coalesce(s.raw_currency,'EUR'), 'Initial signal price');
  end if;

  update public.signals
     set status = 'PROMOTED',
         world_id = p_world_id,
         promoted_candidate_id = v_candidate_id,
         updated_at = now()
   where id = p_signal_id;

  perform public.initialize_candidate_gates(v_candidate_id);

  return v_candidate_id;
end;
$$;

grant execute on function public.promote_signal_to_candidate(uuid, uuid, text) to authenticated;

create or replace view public.v_evaluation_dimension_scores
with (security_invoker = true)
as
select
  ei.evaluation_id,
  ei.dimension,
  round(
    sum(ei.score::numeric * ei.item_weight) filter (where ei.score is not null)
      / nullif(sum(ei.item_weight) filter (where ei.score is not null), 0),
    1
  ) as dimension_score,
  round(
    sum(ei.confidence_percent::numeric * ei.item_weight)
      / nullif(sum(ei.item_weight), 0),
    1
  ) as dimension_confidence,
  count(*) as criterion_count,
  count(*) filter (where ei.score is not null) as scored_count,
  count(*) filter (where ei.evidence_state = 'UNKNOWN') as unknown_count
from public.evaluation_items ei
group by ei.evaluation_id, ei.dimension;

create or replace view public.v_evaluation_scores
with (security_invoker = true)
as
select
  e.id as evaluation_id,
  e.candidate_id,
  e.version_no,
  e.status,
  round(
    sum(ds.dimension_score * w.weight) filter (where ds.dimension_score is not null)
      / nullif(sum(w.weight) filter (where ds.dimension_score is not null), 0),
    1
  ) as compass_score,
  round(
    sum(coalesce(ds.dimension_confidence,0) * w.weight)
      / nullif(sum(w.weight),0),
    1
  ) as confidence_percent,
  e.created_at,
  e.finalized_at
from public.evaluations e
join public.evaluation_dimension_weights w on w.evaluation_id = e.id
left join public.v_evaluation_dimension_scores ds
  on ds.evaluation_id = e.id and ds.dimension = w.dimension
group by e.id, e.candidate_id, e.version_no, e.status, e.created_at, e.finalized_at;

create or replace view public.v_candidate_gate_summary
with (security_invoker = true)
as
select
  c.id as candidate_id,
  count(g.id) as gate_count,
  count(g.id) filter (where g.state = 'PASS') as passed_count,
  count(g.id) filter (where g.state = 'FAIL') as failed_count,
  count(g.id) filter (where g.state = 'UNKNOWN') as unknown_count,
  count(g.id) filter (where g.is_critical and g.state = 'FAIL') as critical_failed_count,
  count(g.id) filter (where g.is_critical and g.state = 'UNKNOWN') as critical_unknown_count
from public.candidates c
left join public.candidate_gates g on g.candidate_id = c.id
group by c.id;

create or replace view public.v_candidate_latest_evaluation
with (security_invoker = true)
as
select *
from (
  select
    s.*,
    row_number() over (
      partition by s.candidate_id
      order by (s.status = 'FINAL') desc, s.version_no desc, s.created_at desc
    ) as rn
  from public.v_evaluation_scores s
) x
where x.rn = 1;

create or replace view public.v_candidate_radar
with (security_invoker = true)
as
select
  c.id,
  c.world_id,
  w.code as world_code,
  w.name as world_name,
  c.status,
  c.title,
  c.asset_kind,
  c.country_code,
  c.region,
  c.municipality,
  c.settlement,
  c.asking_price,
  c.currency,
  c.area_m2,
  c.price_per_m2,
  c.listing_status,
  c.last_seen_at,
  econ.total_phase1_capital,
  le.evaluation_id,
  le.compass_score,
  le.confidence_percent,
  gs.critical_failed_count,
  gs.critical_unknown_count,
  gs.failed_count,
  gs.unknown_count,
  case
    when coalesce(gs.critical_failed_count,0) > 0 then 'BLOCKED'
    when le.compass_score >= 90 then 'HOT'
    when le.compass_score >= 80 then 'STRONG'
    when le.compass_score >= 70 then 'WATCH'
    when le.compass_score is not null then 'LOW'
    else 'UNSCORED'
  end as recommendation
from public.candidates c
join public.worlds w on w.id = c.world_id
left join public.candidate_economics econ on econ.candidate_id = c.id
left join public.v_candidate_latest_evaluation le on le.candidate_id = c.id
left join public.v_candidate_gate_summary gs on gs.candidate_id = c.id;

grant select on public.v_evaluation_dimension_scores to authenticated;
grant select on public.v_evaluation_scores to authenticated;
grant select on public.v_candidate_gate_summary to authenticated;
grant select on public.v_candidate_latest_evaluation to authenticated;
grant select on public.v_candidate_radar to authenticated;
