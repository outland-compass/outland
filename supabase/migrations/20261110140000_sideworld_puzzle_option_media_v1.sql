-- SIDEWORLD Puzzle Option Media V1
-- Additive, private-only binding of existing approved quest assets to immutable
-- puzzle options. No release document / engine content hash / legacy media changes.
-- Apply ONLY after explicit production authorization and backup + restore check.
-- Precondition: quest_releases and quest_visual_assets from 20261015210824.
DO $preflight$
BEGIN
  IF to_regclass('canon.quest_releases') IS NULL OR
     to_regclass('canon.quest_visual_assets') IS NULL OR
     to_regclass('shared.user_roles') IS NULL OR
     to_regclass('canon.quest_puzzle_option_media') IS NOT NULL THEN
    RAISE EXCEPTION 'Puzzle option media prerequisite drift or already installed';
  END IF;
END
$preflight$;

CREATE TABLE canon.quest_puzzle_option_media (
  release_id uuid NOT NULL REFERENCES canon.quest_releases(id) ON DELETE RESTRICT,
  scene_id text NOT NULL CHECK (scene_id ~ '^[a-z0-9][a-z0-9._-]{0,127}$'),
  puzzle_id text NOT NULL CHECK (puzzle_id ~ '^[a-z0-9][a-z0-9_-]{0,63}$'),
  option_id text NOT NULL CHECK (option_id ~ '^[a-z0-9][a-z0-9_-]{0,63}$'),
  asset_id uuid NOT NULL REFERENCES canon.quest_visual_assets(id) ON DELETE RESTRICT,
  display_stage text NOT NULL DEFAULT 'before'
    CHECK (display_stage IN ('before')),
  created_by uuid NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (release_id,scene_id,puzzle_id,option_id),
  UNIQUE (release_id,scene_id,puzzle_id,asset_id)
);
CREATE INDEX quest_puzzle_option_media_asset_idx
  ON canon.quest_puzzle_option_media(asset_id);
ALTER TABLE canon.quest_puzzle_option_media ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON canon.quest_puzzle_option_media FROM PUBLIC, anon, authenticated;
-- The canonical table has zero browser policies. Access is via narrow
-- service-role-only RPCs after either Studio owner check or Player entitlement.

CREATE FUNCTION public.sideworld_quest_puzzle_option_media_bind_v1(
  p_actor uuid,p_release uuid,p_scene text,p_puzzle text,p_option text,p_asset uuid
) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $fn$
DECLARE r canon.quest_releases; a canon.quest_visual_assets;
BEGIN
  IF p_actor IS NULL OR NOT EXISTS (
     SELECT 1 FROM shared.user_roles u WHERE u.user_id=p_actor
       AND u.role::text IN ('OWNER','ADMIN')
  ) THEN RAISE EXCEPTION 'Studio owner or admin required'; END IF;
  SELECT * INTO r FROM canon.quest_releases WHERE id=p_release;
  SELECT * INTO a FROM canon.quest_visual_assets WHERE id=p_asset;
  IF r.id IS NULL OR a.id IS NULL OR
    r.visibility NOT IN ('private','private_qa') OR r.published_at IS NOT NULL OR
    a.draft_id<>r.source_draft_id OR a.revision<>r.source_revision OR
    a.visual_role<>'puzzle_evidence' OR a.source_kind NOT IN ('manual_illustration','ai_illustration') OR
    a.approval_status<>'approved' OR a.approved_by IS NULL OR a.approved_at IS NULL OR
    a.storage_bucket<>'sideworld-quest-media' OR a.mime_type<>'image/webp' OR
    a.storage_path<>(a.draft_id::text||'/r'||a.revision::text||'/'||a.source_sha256||'.webp') OR
    p_scene !~ '^[a-z0-9][a-z0-9._-]{0,127}$' OR
    p_puzzle !~ '^[a-z0-9][a-z0-9_-]{0,63}$' OR
    p_option !~ '^[a-z0-9][a-z0-9_-]{0,63}$' OR
    NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(r.document->'scenes') s
      WHERE s->>'id'=p_scene AND s->'puzzle'->>'id'=p_puzzle AND
        EXISTS (SELECT 1 FROM jsonb_array_elements(s->'puzzle'->'options') o
                WHERE o->>'id'=p_option)
    )
  THEN RAISE EXCEPTION 'Unapproved or out-of-scope puzzle option media'; END IF;
  INSERT INTO canon.quest_puzzle_option_media
    (release_id,scene_id,puzzle_id,option_id,asset_id,created_by)
  VALUES(p_release,p_scene,p_puzzle,p_option,p_asset,p_actor)
  ON CONFLICT DO NOTHING;
  -- No overwrite. A reattempt is idempotent only for the exact same asset.
  RETURN EXISTS (
    SELECT 1 FROM canon.quest_puzzle_option_media b
    WHERE b.release_id=p_release AND b.scene_id=p_scene AND b.puzzle_id=p_puzzle
      AND b.option_id=p_option AND b.asset_id=p_asset
  );
END
$fn$;

CREATE FUNCTION public.sideworld_quest_puzzle_option_media_for_release_v1(
  p_release uuid,p_scene text,p_puzzle text
) RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $fn$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
      'optionId',b.option_id,'assetId',a.id,'sha256',a.source_sha256,
      'mimeType',a.mime_type,'width',a.width,'height',a.height,
      'briefId',a.brief_id,'visualRole',a.visual_role,
      'storagePath',a.storage_path
    ) ORDER BY b.option_id),'[]'::jsonb)
  FROM canon.quest_releases r
  JOIN canon.quest_puzzle_option_media b
    ON b.release_id=r.id AND b.scene_id=p_scene AND b.puzzle_id=p_puzzle
  JOIN canon.quest_visual_assets a ON a.id=b.asset_id
  WHERE r.id=p_release AND r.visibility IN ('private','private_qa')
    AND r.published_at IS NULL AND a.draft_id=r.source_draft_id
    AND a.revision=r.source_revision AND a.approval_status='approved'
    AND a.approved_by IS NOT NULL AND a.approved_at IS NOT NULL
    AND a.visual_role='puzzle_evidence'
    AND a.source_kind IN ('manual_illustration','ai_illustration')
    AND a.mime_type='image/webp' AND a.storage_bucket='sideworld-quest-media'
    AND a.storage_path=(a.draft_id::text||'/r'||a.revision::text||'/'||a.source_sha256||'.webp')
    AND EXISTS (
      SELECT 1 FROM jsonb_array_elements(r.document->'scenes') s
      WHERE s->>'id'=p_scene AND s->'puzzle'->>'id'=p_puzzle
        AND EXISTS (SELECT 1 FROM jsonb_array_elements(s->'puzzle'->'options') o
                    WHERE o->>'id'=b.option_id)
    );
$fn$;

REVOKE ALL ON FUNCTION public.sideworld_quest_puzzle_option_media_bind_v1(uuid,uuid,text,text,text,uuid)
  FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.sideworld_quest_puzzle_option_media_for_release_v1(uuid,text,text)
  FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sideworld_quest_puzzle_option_media_bind_v1(uuid,uuid,text,text,text,uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.sideworld_quest_puzzle_option_media_for_release_v1(uuid,text,text)
  TO service_role;

COMMENT ON TABLE canon.quest_puzzle_option_media IS
 'Immutable one-media-per-option private QA attachments to existing canonical quest assets. No direct client access, no answer key, no published release writes.';
