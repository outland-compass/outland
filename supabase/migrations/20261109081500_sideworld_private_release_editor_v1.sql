-- SIDEWORLD private QA release editorial editor V1.
-- Only service_role can invoke these RPCs; Studio authenticates the OWNER/ADMIN
-- before passing the verified actor. No direct client table grants or RLS changes.
-- The existing private-only release guard remains in force.
CREATE OR REPLACE FUNCTION public.sideworld_private_release_editor_get_v1(
  p_actor uuid, p_release uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE r canon.quest_releases;
BEGIN
  IF p_actor IS NULL OR p_release IS NULL OR NOT EXISTS(
    SELECT 1 FROM shared.user_roles u WHERE u.user_id=p_actor
      AND u.role::text IN ('OWNER','ADMIN')
  ) THEN RETURN jsonb_build_object('kind','unavailable'); END IF;
  SELECT * INTO r FROM canon.quest_releases WHERE id=p_release;
  IF NOT FOUND OR r.visibility NOT IN ('private','private_qa') THEN
    RETURN jsonb_build_object('kind','unavailable');
  END IF;
  RETURN jsonb_build_object('kind','ok','releaseId',r.id,
     'draftId',r.source_draft_id,'revision',r.source_revision,
     'visibility',r.visibility,'contentHash',r.engine_content_hash,
     'document',r.document,'updatedAt',r.updated_at);
END
$fn$;

CREATE OR REPLACE FUNCTION public.sideworld_private_release_editor_save_v1(
  p_actor uuid, p_release uuid, p_expected_hash text,
  p_document jsonb, p_new_hash text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE r canon.quest_releases;
BEGIN
  IF p_actor IS NULL OR p_release IS NULL OR NOT EXISTS(
    SELECT 1 FROM shared.user_roles u WHERE u.user_id=p_actor
      AND u.role::text IN ('OWNER','ADMIN')
  ) THEN RETURN jsonb_build_object('kind','unavailable'); END IF;
  IF p_expected_hash IS NULL OR p_expected_hash !~ '^[0-9a-f]{64}$'
     OR p_new_hash IS NULL OR p_new_hash !~ '^[0-9a-f]{64}$'
     OR p_document IS NULL OR jsonb_typeof(p_document)<>'object'
     OR pg_column_size(p_document)>250000 OR p_document->>'contractVersion'<>'1'
  THEN RETURN jsonb_build_object('kind','invalid'); END IF;
  SELECT * INTO r FROM canon.quest_releases WHERE id=p_release FOR UPDATE;
  IF NOT FOUND OR r.visibility NOT IN ('private','private_qa') THEN
    RETURN jsonb_build_object('kind','unavailable');
  END IF;
  IF r.engine_content_hash<>p_expected_hash THEN
    RETURN jsonb_build_object('kind','conflict');
  END IF;
  IF r.document=p_document AND r.engine_content_hash=p_new_hash THEN
    RETURN jsonb_build_object('kind','unchanged','contentHash',r.engine_content_hash);
  END IF;
  -- A changed document and changed hash are required together by the
  -- canonical release guard; never weaken that guard here.
  IF r.document=p_document OR r.engine_content_hash=p_new_hash THEN
    RETURN jsonb_build_object('kind','invalid');
  END IF;
  UPDATE canon.quest_releases SET document=p_document,engine_content_hash=p_new_hash
    WHERE id=r.id;
  RETURN jsonb_build_object('kind','saved','releaseId',r.id,
     'revision',r.source_revision,'contentHash',p_new_hash);
END
$fn$;

REVOKE ALL ON FUNCTION public.sideworld_private_release_editor_get_v1(uuid,uuid)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sideworld_private_release_editor_save_v1(uuid,uuid,text,jsonb,text)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.sideworld_private_release_editor_get_v1(uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.sideworld_private_release_editor_save_v1(uuid,uuid,text,jsonb,text) TO service_role;
