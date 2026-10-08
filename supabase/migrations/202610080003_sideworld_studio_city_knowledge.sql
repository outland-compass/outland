-- SIDEWORLD Studio V0-F — City Knowledge Base read/write boundary.
-- Existing geo tables are reused; no new domain tables are introduced.
-- Private geo schema remains outside Data API exposure.

create or replace function public.sideworld_studio_city_knowledge(p_city_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
select jsonb_build_object(
  'city',
    (
      select jsonb_build_object(
        'id', c.id,
        'countryCode', c.country_code,
        'slug', c.slug,
        'name', c.name,
        'region', c.region,
        'timezone', c.timezone,
        'defaultLocale', c.default_locale,
        'status', c.status,
        'verificationStatus', c.verification_status
      )
      from geo.cities c
      where c.id = p_city_id
    ),
  'locations',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', l.id,
          'cityId', l.city_id,
          'slug', l.slug,
          'name', l.name,
          'locationType', l.location_type,
          'latitude', l.latitude,
          'longitude', l.longitude,
          'addressText', l.address_text,
          'publicAccess', l.public_access,
          'accessibilityProfile', l.accessibility_profile,
          'safetyProfile', l.safety_profile,
          'openingHours', l.opening_hours,
          'verificationStatus', l.verification_status,
          'fieldVerifiedAt', l.field_verified_at,
          'metadata', l.metadata
        )
        order by l.name, l.id
      )
      from geo.locations l
      where l.city_id = p_city_id
    ), '[]'::jsonb),
  'facts',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', f.id,
          'cityId', f.city_id,
          'locationId', f.location_id,
          'factKey', f.fact_key,
          'statement', f.statement,
          'factType', f.fact_type,
          'verificationStatus', f.verification_status,
          'confidence', f.confidence,
          'validFrom', f.valid_from,
          'validTo', f.valid_to,
          'lastVerifiedAt', f.last_verified_at,
          'metadata', f.metadata
        )
        order by f.fact_key, f.id
      )
      from geo.location_facts f
      where f.city_id = p_city_id
    ), '[]'::jsonb),
  'sources',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'id', s.id,
          'url', s.url,
          'publisher', s.publisher,
          'title', s.title,
          'sourceType', s.source_type,
          'publishedAt', s.published_at,
          'retrievedAt', s.retrieved_at,
          'trustTier', s.trust_tier,
          'metadata', s.metadata
        )
        order by s.title, s.id
      )
      from geo.sources s
      where exists (
        select 1
        from geo.fact_sources fs
        join geo.location_facts f on f.id = fs.fact_id
        where fs.source_id = s.id and f.city_id = p_city_id
      )
    ), '[]'::jsonb),
  'factSources',
    coalesce((
      select jsonb_agg(
        jsonb_build_object(
          'factId', fs.fact_id,
          'sourceId', fs.source_id,
          'supportType', fs.support_type,
          'note', fs.note
        )
        order by fs.fact_id, fs.source_id
      )
      from geo.fact_sources fs
      join geo.location_facts f on f.id = fs.fact_id
      where f.city_id = p_city_id
    ), '[]'::jsonb)
);
$$;

create or replace function public.sideworld_studio_save_location(
  p_id uuid,
  p_city_id uuid,
  p_slug text,
  p_name text,
  p_location_type text,
  p_latitude numeric,
  p_longitude numeric,
  p_address_text text,
  p_public_access boolean,
  p_verification_status text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid;
begin
  if p_city_id is null then raise exception 'city_id is required'; end if;
  if btrim(coalesce(p_slug,'')) = '' then raise exception 'slug is required'; end if;
  if btrim(coalesce(p_name,'')) = '' then raise exception 'name is required'; end if;
  if p_latitude is null or p_longitude is null then raise exception 'location coordinates are required'; end if;

  if p_id is null then
    insert into geo.locations(
      city_id,slug,name,location_type,latitude,longitude,address_text,public_access,verification_status
    )
    values(
      p_city_id,p_slug,p_name,coalesce(nullif(btrim(p_location_type),''),'poi'),
      p_latitude,p_longitude,nullif(btrim(p_address_text),''),p_public_access,
      coalesce(nullif(btrim(p_verification_status),''),'unverified')
    )
    on conflict (city_id,slug) do update set
      name=excluded.name,
      location_type=excluded.location_type,
      latitude=excluded.latitude,
      longitude=excluded.longitude,
      address_text=excluded.address_text,
      public_access=excluded.public_access,
      verification_status=excluded.verification_status,
      updated_at=now()
    returning id into v_id;
  else
    update geo.locations set
      city_id=p_city_id,
      slug=p_slug,
      name=p_name,
      location_type=coalesce(nullif(btrim(p_location_type),''),'poi'),
      latitude=p_latitude,
      longitude=p_longitude,
      address_text=nullif(btrim(p_address_text),''),
      public_access=p_public_access,
      verification_status=coalesce(nullif(btrim(p_verification_status),''),'unverified'),
      updated_at=now()
    where id=p_id
    returning id into v_id;
    if v_id is null then raise exception 'Location not found: %', p_id; end if;
  end if;

  return v_id;
end;
$$;

create or replace function public.sideworld_studio_save_location_fact(
  p_id uuid,
  p_city_id uuid,
  p_location_id uuid,
  p_fact_key text,
  p_statement text,
  p_fact_type text,
  p_verification_status text,
  p_confidence numeric
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid;
begin
  if p_city_id is null then raise exception 'city_id is required'; end if;
  if btrim(coalesce(p_fact_key,'')) = '' then raise exception 'fact_key is required'; end if;
  if btrim(coalesce(p_statement,'')) = '' then raise exception 'statement is required'; end if;

  if p_location_id is not null and not exists (
    select 1 from geo.locations l where l.id=p_location_id and l.city_id=p_city_id
  ) then
    raise exception 'location_id does not belong to city_id';
  end if;

  if p_id is null then
    insert into geo.location_facts(
      city_id,location_id,fact_key,statement,fact_type,verification_status,confidence
    )
    values(
      p_city_id,p_location_id,p_fact_key,p_statement,
      coalesce(nullif(btrim(p_fact_type),''),'general'),
      coalesce(nullif(btrim(p_verification_status),''),'unverified'),
      p_confidence
    )
    on conflict (city_id,fact_key) do update set
      location_id=excluded.location_id,
      statement=excluded.statement,
      fact_type=excluded.fact_type,
      verification_status=excluded.verification_status,
      confidence=excluded.confidence,
      updated_at=now()
    returning id into v_id;
  else
    update geo.location_facts set
      city_id=p_city_id,
      location_id=p_location_id,
      fact_key=p_fact_key,
      statement=p_statement,
      fact_type=coalesce(nullif(btrim(p_fact_type),''),'general'),
      verification_status=coalesce(nullif(btrim(p_verification_status),''),'unverified'),
      confidence=p_confidence,
      updated_at=now()
    where id=p_id
    returning id into v_id;
    if v_id is null then raise exception 'Location fact not found: %', p_id; end if;
  end if;

  return v_id;
end;
$$;

create or replace function public.sideworld_studio_save_source(
  p_id uuid,
  p_url text,
  p_publisher text,
  p_title text,
  p_source_type text,
  p_published_at timestamptz,
  p_trust_tier text
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_id uuid;
begin
  if btrim(coalesce(p_title,'')) = '' then raise exception 'title is required'; end if;
  if btrim(coalesce(p_source_type,'')) = '' then raise exception 'source_type is required'; end if;

  if p_id is null then
    insert into geo.sources(url,publisher,title,source_type,published_at,trust_tier)
    values(
      nullif(btrim(p_url),''),
      nullif(btrim(p_publisher),''),
      p_title,
      p_source_type,
      p_published_at,
      nullif(btrim(p_trust_tier),'')
    )
    returning id into v_id;
  else
    update geo.sources set
      url=nullif(btrim(p_url),''),
      publisher=nullif(btrim(p_publisher),''),
      title=p_title,
      source_type=p_source_type,
      published_at=p_published_at,
      trust_tier=nullif(btrim(p_trust_tier),'')
    where id=p_id
    returning id into v_id;
    if v_id is null then raise exception 'Source not found: %', p_id; end if;
  end if;

  return v_id;
end;
$$;

create or replace function public.sideworld_studio_save_fact_source(
  p_fact_id uuid,
  p_source_id uuid,
  p_support_type text,
  p_note text
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into geo.fact_sources(fact_id,source_id,support_type,note)
  values(
    p_fact_id,p_source_id,
    coalesce(nullif(btrim(p_support_type),''),'supports'),
    nullif(btrim(p_note),'')
  )
  on conflict (fact_id,source_id) do update set
    support_type=excluded.support_type,
    note=excluded.note;

  return p_fact_id::text || ':' || p_source_id::text;
end;
$$;

revoke all on function public.sideworld_studio_city_knowledge(uuid) from public, anon, authenticated, service_role;
revoke all on function public.sideworld_studio_save_location(uuid,uuid,text,text,text,numeric,numeric,text,boolean,text) from public, anon, authenticated, service_role;
revoke all on function public.sideworld_studio_save_location_fact(uuid,uuid,uuid,text,text,text,text,numeric) from public, anon, authenticated, service_role;
revoke all on function public.sideworld_studio_save_source(uuid,text,text,text,text,timestamptz,text) from public, anon, authenticated, service_role;
revoke all on function public.sideworld_studio_save_fact_source(uuid,uuid,text,text) from public, anon, authenticated, service_role;

grant execute on function public.sideworld_studio_city_knowledge(uuid) to service_role;
grant execute on function public.sideworld_studio_save_location(uuid,uuid,text,text,text,numeric,numeric,text,boolean,text) to service_role;
grant execute on function public.sideworld_studio_save_location_fact(uuid,uuid,uuid,text,text,text,text,numeric) to service_role;
grant execute on function public.sideworld_studio_save_source(uuid,text,text,text,text,timestamptz,text) to service_role;
grant execute on function public.sideworld_studio_save_fact_source(uuid,uuid,text,text) to service_role;
