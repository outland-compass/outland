-- SIDEWORLD permanent real-user private-release entitlements V1.
-- Additive. Does NOT replace existing QA grants or rewrite releases.
-- All actor IDs belong to existing auth.users (no test accounts).
-- Rollback: restore old player.can_use_release_v1 definition, then drop
-- public.sideworld_player_release_access_* functions and player.release_access.
CREATE TABLE IF NOT EXISTS player.release_access (
 release_id uuid NOT NULL REFERENCES canon.quest_releases(id) ON DELETE CASCADE,
 actor_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 granted_by uuid NOT NULL REFERENCES auth.users(id),
 granted_at timestamptz NOT NULL DEFAULT now(),
 revoked_at timestamptz,
 revoked_by uuid REFERENCES auth.users(id),
 PRIMARY KEY (release_id,actor_id)
);
CREATE INDEX IF NOT EXISTS release_access_actor_idx
 ON player.release_access(actor_id,release_id) WHERE revoked_at IS NULL;
ALTER TABLE player.release_access ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON player.release_access FROM PUBLIC,anon,authenticated;
-- Preserve service-role visibility for internal inspected services only.
GRANT SELECT ON player.release_access TO service_role;

CREATE OR REPLACE FUNCTION public.sideworld_player_release_access_grant_v1(
 p_operator uuid,p_release_id uuid,p_actor_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
 IF NOT player.is_qa_operator_v1(p_operator) THEN
  RETURN jsonb_build_object('kind','unavailable');
 END IF;
 IF p_actor_id IS NULL OR p_release_id IS NULL OR
    NOT EXISTS(SELECT 1 FROM auth.users u WHERE u.id=p_actor_id) OR
    NOT EXISTS(SELECT 1 FROM canon.quest_releases r WHERE r.id=p_release_id
      AND r.visibility='private_qa') THEN
  RETURN jsonb_build_object('kind','unavailable');
 END IF;
 INSERT INTO player.release_access(release_id,actor_id,granted_by)
 VALUES(p_release_id,p_actor_id,p_operator)
 ON CONFLICT(release_id,actor_id) DO UPDATE
 SET revoked_at=NULL,revoked_by=NULL,granted_at=now(),granted_by=excluded.granted_by;
 RETURN jsonb_build_object('kind','granted','releaseId',p_release_id,'actorId',p_actor_id);
END
$$;

CREATE OR REPLACE FUNCTION public.sideworld_player_release_access_revoke_v1(
 p_operator uuid,p_release_id uuid,p_actor_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path TO ''
AS $$
BEGIN
 IF NOT player.is_qa_operator_v1(p_operator) THEN
  RETURN jsonb_build_object('kind','unavailable');
 END IF;
 UPDATE player.release_access SET revoked_at=coalesce(revoked_at,now()),
  revoked_by=case when revoked_at IS NULL then p_operator else revoked_by end
 WHERE release_id=p_release_id AND actor_id=p_actor_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('kind','unavailable'); END IF;
 RETURN jsonb_build_object('kind','revoked','releaseId',p_release_id,'actorId',p_actor_id);
END
$$;

-- Backward compatible: existing time-limited grants still work, but new
-- real-user entitlements do NOT expire. No release becomes globally public.
CREATE OR REPLACE FUNCTION player.can_use_release_v1(p_actor uuid,p_release uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $$
 SELECT coalesce(p_actor IS NOT NULL AND EXISTS(
  SELECT 1 FROM auth.users u WHERE u.id=p_actor
 ),false) AND EXISTS(
  SELECT 1 FROM canon.quest_releases r WHERE r.id=p_release AND (
   (r.visibility='published' AND r.editorial_approved_at IS NOT NULL
     AND r.field_verified_at IS NOT NULL AND r.media_cleared_at IS NOT NULL
     AND r.published_at IS NOT NULL)
   OR (r.visibility='private_qa' AND (
      EXISTS(SELECT 1 FROM player.release_access x
       WHERE x.release_id=r.id AND x.actor_id=p_actor AND x.revoked_at IS NULL)
      OR EXISTS(SELECT 1 FROM player.qa_access g
       WHERE g.release_id=r.id AND g.actor_id=p_actor AND
        g.expires_at>now() AND g.revoked_at IS NULL)
   ))
  )
 );
$$;

REVOKE ALL ON FUNCTION public.sideworld_player_release_access_grant_v1(uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.sideworld_player_release_access_revoke_v1(uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.sideworld_player_release_access_grant_v1(uuid,uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.sideworld_player_release_access_revoke_v1(uuid,uuid,uuid) TO service_role;

-- Enforce role, referential integrity, and deny browser-level writes.
COMMENT ON TABLE player.release_access IS
 'Persistent access for real authenticated SIDEWORLD users to private releases. Separate from expiring legacy QA grants.';
