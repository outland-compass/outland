-- Promote a discovery-hunt signal without forcing it into an OUTLAND World.
-- The candidate keeps world_id NULL and is linked to its saved search profile.

create or replace function public.promote_discovery_signal_to_candidate(
  p_signal_id uuid,
  p_search_profile_id uuid,
  p_title text default null
)
returns uuid
language plpgsql
set search_path to 'public'
as $function$
declare
  s land.signals%rowtype;
  p land.search_profiles%rowtype;
  v_candidate_id uuid;
  v_source_id uuid;
begin
  if not public.can_analyze() then
    raise exception 'Not authorized';
  end if;

  select * into s from land.signals where id = p_signal_id for update;
  if not found then raise exception 'Signal not found'; end if;

  select * into p from land.search_profiles where id = p_search_profile_id and is_active = true;
  if not found then raise exception 'Active search profile not found'; end if;

  if s.promoted_candidate_id is not null then
    insert into land.candidate_search_profiles(candidate_id, search_profile_id, notes)
    values (s.promoted_candidate_id, p.id, 'Promoted from Discovery Hunt signal.')
    on conflict (candidate_id, search_profile_id) do nothing;
    return s.promoted_candidate_id;
  end if;

  insert into land.candidates(
    world_id, title, asset_kind, development_model,
    asking_price, currency, area_m2,
    description, date_discovered, last_seen_at, created_by
  )
  values (
    null,
    coalesce(p_title, s.raw_title, 'Untitled candidate'),
    case
      when (s.extracted_payload ->> 'asset_kind') in ('LAND','BUILDING','FLOATING','MOBILE','OTHER')
        then (s.extracted_payload ->> 'asset_kind')::public.asset_kind
      else p.asset_kind
    end,
    p.development_model,
    s.raw_price, coalesce(s.raw_currency, 'EUR'), s.raw_area_m2,
    s.raw_description, s.discovered_at::date, s.last_seen_at, auth.uid()
  )
  returning id into v_candidate_id;

  insert into land.candidate_search_profiles(candidate_id, search_profile_id, notes)
  values (v_candidate_id, p.id, 'Promoted from Discovery Hunt signal.');

  insert into land.candidate_sources(
    candidate_id, signal_id, source_name, source_url, source_listing_id,
    first_seen_at, last_seen_at, source_snapshot
  )
  values (
    v_candidate_id, s.id, coalesce(s.source_name,'Unknown source'), s.source_url,
    s.source_listing_id, s.discovered_at, s.last_seen_at,
    jsonb_build_object('raw_payload', s.raw_payload, 'extracted_payload', s.extracted_payload)
  )
  returning id into v_source_id;

  if s.raw_price is not null then
    insert into land.candidate_price_history(candidate_id, source_id, observed_at, price, currency, note)
    values (v_candidate_id, v_source_id, s.discovered_at, s.raw_price, coalesce(s.raw_currency,'EUR'), 'Initial discovery signal price');
  end if;

  update land.signals
     set status = 'PROMOTED',
         promoted_candidate_id = v_candidate_id,
         updated_at = now()
   where id = p_signal_id;

  -- No World-specific gates/evaluation are initialized here. That happens only after
  -- a World is deliberately assigned.
  return v_candidate_id;
end;
$function$;

grant execute on function public.promote_discovery_signal_to_candidate(uuid, uuid, text) to authenticated;
