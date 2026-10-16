-- Staging-only, rollback-safe contract smoke test for permanent private releases.
-- Uses the EXISTING OWNER Supabase Auth account, never creates an Auth or QA
-- tester account, and rolls back all synthetic quest/release data.
-- Do not run as production smoke test: isolated staging only.
DO $contract$
DECLARE
 who uuid; u uuid; f uuid; s uuid; city uuid; draft uuid:=gen_random_uuid();
 denied uuid:=gen_random_uuid(); result jsonb; v uuid;
BEGIN
 BEGIN
  SELECT user_id INTO STRICT who FROM shared.user_roles WHERE role::text='OWNER' LIMIT 1;
  SELECT id INTO STRICT u FROM universe.universes LIMIT 1;
  SELECT id INTO STRICT f FROM canon.franchises LIMIT 1;
  SELECT id INTO STRICT s FROM canon.series LIMIT 1;
  SELECT id INTO STRICT city FROM geo.cities LIMIT 1;
  INSERT INTO canon.quest_drafts(id,universe_id,franchise_id,series_id,city_id,
     created_by,request_key,input_snapshot,status,revision)
    VALUES(draft,u,f,s,city,who,gen_random_uuid(),'{}'::jsonb,'draft',1);
  INSERT INTO canon.quest_draft_revisions(draft_id,revision,document,diagnostics,edited_by)
    VALUES(draft,1,'{"contractVersion":1}'::jsonb,'[]'::jsonb,who);
  result:=public.sideworld_player_private_release_create_v1(who,draft,1,repeat('a',64));
  IF result->>'kind'<>'created' THEN RAISE EXCEPTION 'Private release creation failed'; END IF;
  v:=(result->>'releaseId')::uuid;
  IF NOT player.can_use_release_v1(who,v)
    THEN RAISE EXCEPTION 'Existing OWNER account not authorized'; END IF;
  IF player.can_use_release_v1(denied,v)
    THEN RAISE EXCEPTION 'Unknown account authorized'; END IF;
  IF (public.sideworld_player_private_release_create_v1(who,draft,1,repeat('a',64))->>'kind')<>'existing'
    THEN RAISE EXCEPTION 'Idempotent retry failed'; END IF;
  IF (public.sideworld_player_private_release_create_v1(who,draft,1,repeat('b',64))->>'kind')<>'conflict'
    THEN RAISE EXCEPTION 'Contradictory hash accepted'; END IF;
  IF (public.sideworld_player_private_access_set_v1(denied,v,who,true)->>'kind')<>'unavailable'
    THEN RAISE EXCEPTION 'Non-owner elevated permissions'; END IF;
  IF (public.sideworld_player_private_access_set_v1(who,v,who,true)->>'kind')<>'granted'
    THEN RAISE EXCEPTION 'Existing-account permission grant failed'; END IF;
  IF (public.sideworld_player_private_access_set_v1(who,v,who,false)->>'kind')<>'revoked'
    THEN RAISE EXCEPTION 'Permanent permission revocation failed'; END IF;
  RAISE EXCEPTION 'SIDEWORLD_EXPECTED_ROLLBACK';
 EXCEPTION WHEN others THEN
  IF SQLERRM<>'SIDEWORLD_EXPECTED_ROLLBACK' THEN RAISE; END IF;
 END;
END $contract$;
