-- SIDEWORLD DNA status RPC test proposal for a disposable local DB
-- Run ONLY after the reviewed status RPC migration was applied locally.
-- Every synthetic data mutation below is rolled back.
begin;
do $test$
declare
  uid uuid := gen_random_uuid();
  a uuid := gen_random_uuid();
  b uuid := gen_random_uuid();
  c uuid := gen_random_uuid();
  payload jsonb;
  rows jsonb;
  spoiler text := 'SEALED_PRIVATE_FRANCHISE_BIBLE_SENTINEL';
begin
  if has_function_privilege('anon', 'public.sideworld_studio_dna_metadata_status_v1(text)', 'EXECUTE')
     or has_function_privilege('authenticated', 'public.sideworld_studio_dna_metadata_status_v1(text)', 'EXECUTE')
     or not has_function_privilege('service_role', 'public.sideworld_studio_dna_metadata_status_v1(text)', 'EXECUTE')
  then raise exception 'DNA private status RPC grants invalid'; end if;

  insert into universe.universes (id, slug, name, visibility, status, metadata)
  values (uid, 'dna-status-test-sandbox', 'Synthetic safe test', 'private', 'draft',
          jsonb_build_object('sealed_story_arc', spoiler));

  insert into canon.franchises (id, universe_id, slug, name, status, canon_version, metadata)
  values
    (a, uid, 'absent', 'Synthetic absent', 'draft', 1,
     jsonb_build_object('franchise_bible', spoiler)),
    (b, uid, 'existing', 'Synthetic existing', 'draft', 2,
     jsonb_build_object('experience_dna_v1',
       jsonb_build_object('profileVersion', '1.2.3', 'sealedNarrative', spoiler),
       'sealed_story_arc', spoiler)),
    (c, uid, 'malformed', 'Synthetic malformed', 'draft', 1,
     jsonb_build_object('experience_dna_v1', jsonb_build_array(spoiler)));

  select public.sideworld_studio_dna_metadata_status_v1('dna-status-test-sandbox')
  into payload;

  if payload is null or payload->>'universeId' <> uid::text or
     payload->>'universeSlug' <> 'dna-status-test-sandbox' or
     payload->>'schemaVersion' <> '1' then
     raise exception 'DNA metadata status scope mismatch';
  end if;

  rows := payload->'rows';
  if jsonb_array_length(rows) <> 3 then
    raise exception 'Expected exactly 3 synthetic franchise statuses';
  end if;

  if payload::text like '%' || spoiler || '%' or
     payload::text like '%sealed_story_arc%' or
     payload::text like '%franchise_bible%' or
     payload::text like '%sealedNarrative%'
  then raise exception 'DNA status leaked creator-only metadata'; end if;

  if (select x->>'dnaNamespaceState' from jsonb_array_elements(rows) as x
      where x->>'franchiseSlug'='absent') <> 'absent'
     or (select x->>'dnaNamespaceState' from jsonb_array_elements(rows) as x
      where x->>'franchiseSlug'='existing') <> 'object'
     or (select x->>'profileVersion' from jsonb_array_elements(rows) as x
      where x->>'franchiseSlug'='existing') <> '1.2.3'
     or (select x->>'dnaNamespaceState' from jsonb_array_elements(rows) as x
      where x->>'franchiseSlug'='malformed') <> 'malformed'
  then raise exception 'DNA namespace classification incorrect'; end if;

  if public.sideworld_studio_dna_metadata_status_v1('not-the-synthetic-universe') is not null
     or public.sideworld_studio_dna_metadata_status_v1('../invalid') is not null
  then raise exception 'Cross-universe/invalid input was not denied'; end if;
end
$test$;
rollback;
