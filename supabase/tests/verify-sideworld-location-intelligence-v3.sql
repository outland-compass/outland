-- V3 additive contract and privilege checks; safe on disposable local database.
begin;
do $verify$ declare
  names text[] := array['location_research_candidates','location_hierarchy','location_clues'];
  canon_names text[] := array['location_franchise_fits','location_character_uses','location_clue_uses'];
  n text;
begin
  foreach n in array names loop
    if to_regclass('geo.'||n) is null then raise exception 'Missing geo.%',n; end if;
    if not (select relrowsecurity from pg_class where oid=('geo.'||n)::regclass) then
      raise exception 'RLS disabled on geo.%',n;
    end if;
    if has_table_privilege('anon',('geo.'||n)::regclass,'SELECT')
      or has_table_privilege('authenticated',('geo.'||n)::regclass,'SELECT')
      or has_table_privilege('anon',('geo.'||n)::regclass,'INSERT')
      or has_table_privilege('authenticated',('geo.'||n)::regclass,'INSERT') then
      raise exception 'Unexpected player role grant on geo.%',n;
    end if;
  end loop;
  foreach n in array canon_names loop
    if to_regclass('canon.'||n) is null then raise exception 'Missing canon.%',n; end if;
    if not (select relrowsecurity from pg_class where oid=('canon.'||n)::regclass) then
      raise exception 'RLS disabled on canon.%',n;
    end if;
    if has_table_privilege('anon',('canon.'||n)::regclass,'SELECT')
      or has_table_privilege('authenticated',('canon.'||n)::regclass,'SELECT')
      or has_table_privilege('anon',('canon.'||n)::regclass,'INSERT')
      or has_table_privilege('authenticated',('canon.'||n)::regclass,'INSERT') then
      raise exception 'Unexpected player role grant on canon.%',n;
    end if;
  end loop;
  if has_schema_privilege('anon','geo','USAGE') or has_schema_privilege('authenticated','canon','USAGE') then
    raise exception 'Private geo/canon schema exposed';
  end if;
  if (select column_default from information_schema.columns
      where table_schema='geo' and table_name='location_research_candidates'
        and column_name='navigation_eligible') not like '%true%' then
    raise exception 'Navigation must default allow';
  end if;
  if not exists(select 1 from information_schema.columns
      where table_schema='geo' and table_name='fact_sources' and column_name='source_excerpt') then
    raise exception 'Missing provenance excerpt column';
  end if;
end $verify$;

-- Transactional fixtures: a parent/child must belong to one city; cycles rejected.
do $fixture$ declare
  c uuid; a uuid; b uuid; d uuid; f uuid; v text;
begin
  insert into geo.countries(code,name) values('QX','Location V3 Fixture')
     on conflict(code) do update set name=excluded.name;
  insert into geo.cities(country_code,slug,name,timezone,default_locale)
    values('QX','location-v3-fixture','Location V3 Fixture','Europe/Belgrade','en')
    returning id into c;
  insert into geo.locations(city_id,slug,name,latitude,longitude)
    values(c,'parent-fixture','Parent',45.3,19.8) returning id into a;
  insert into geo.locations(city_id,slug,name,latitude,longitude)
    values(c,'child-fixture','Child',45.3001,19.8001) returning id into b;
  insert into geo.locations(city_id,slug,name,latitude,longitude)
    values(c,'detail-fixture','Detail',45.3002,19.8002) returning id into d;
  insert into geo.location_hierarchy(child_location_id,parent_location_id,city_id)
    values(b,a,c),(d,b,c);
  begin
    insert into geo.location_hierarchy(child_location_id,parent_location_id,city_id)
      values(a,d,c);
    raise exception 'Cycle incorrectly accepted';
  exception when check_violation then null;
  end;
  insert into geo.location_research_candidates(
    city_id,source_key,external_research_id,display_name)
    values(c,'fixture','V3-TEST','Unplaced test research object') returning id into f;
  if not (select navigation_eligible and quest_field_qa_required
          from geo.location_research_candidates where id=f) then
    raise exception 'Research candidate navigation policy incorrect';
  end if;
  insert into geo.location_clues(location_id,clue_key,title,clue_kind)
     values (b,'detail','Historic detail','architectural_detail');
  begin
    insert into geo.location_clues(location_id,clue_key,title,clue_kind,
      reference_latitude,reference_longitude)
      values (b,'bad-coordinate','Missing latitude','viewpoint',null,19.8003);
    raise exception 'Partial coordinate pair incorrectly accepted';
  exception when check_violation then null;
  end;
end $fixture$;
rollback;