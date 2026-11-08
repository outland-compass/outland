-- SIDEWORLD: founder-only private QA releases may be edited in place.
-- Published and retired releases remain immutable. All release provenance
-- and the frozen source draft revision remain pinned. No table or data changes.
--
-- Application must recompute the exact Player-normalized SHA-256 in the same
-- transaction as a document edit. Running QA sessions with the previous hash
-- must be restarted; never silently rewrite player progress.

-- Some legacy upgrade rehearsals intentionally do not install SIDEWORLD yet.
-- Skip those fixtures; production already contains the original function.
DO $sideworld_private_edit$
BEGIN
  IF to_regnamespace('canon') IS NULL
     OR to_regprocedure('canon.sideworld_guard_release_v1()') IS NULL THEN
    RAISE NOTICE 'SIDEWORLD release guard not installed; private QA edit unlock skipped';
  ELSE
    EXECUTE $ddl$
CREATE OR REPLACE FUNCTION canon.sideworld_guard_release_v1()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  authored jsonb;
  edited_document boolean;
  edited_hash boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    RAISE EXCEPTION 'Quest release deletion is disabled';
  END IF;

  IF TG_OP = 'UPDATE' THEN
    -- Preserve release identity, provenance, ownership and creation timestamp.
    IF NEW.id IS DISTINCT FROM OLD.id
       OR NEW.source_draft_id IS DISTINCT FROM OLD.source_draft_id
       OR NEW.source_revision IS DISTINCT FROM OLD.source_revision
       OR NEW.created_by IS DISTINCT FROM OLD.created_by
       OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
      RAISE EXCEPTION 'Quest release identity and provenance are immutable';
    END IF;

    IF (OLD.visibility = 'retired' AND NEW.visibility <> 'retired')
       OR (OLD.visibility = 'published' AND NEW.visibility = 'private_qa') THEN
      RAISE EXCEPTION 'Invalid release lifecycle transition';
    END IF;

    edited_document := NEW.document IS DISTINCT FROM OLD.document;
    edited_hash := NEW.engine_content_hash IS DISTINCT FROM OLD.engine_content_hash;

    IF edited_document OR edited_hash THEN
      -- Private QA may update its own content without forking another revision.
      -- A published or retired source can never be edited.
      IF OLD.visibility NOT IN ('private', 'private_qa')
         OR NEW.visibility IS DISTINCT FROM OLD.visibility THEN
        RAISE EXCEPTION 'Published or retired release content is immutable';
      END IF;
      IF edited_document IS DISTINCT FROM edited_hash THEN
        RAISE EXCEPTION 'Quest release content and source are immutable';
      END IF;
    END IF;

    NEW.updated_at := now();
    RETURN NEW;
  END IF;

  -- Keep exact-copy-on-create semantics to protect initial release provenance.
  SELECT r.document INTO authored
  FROM canon.quest_draft_revisions AS r
  WHERE r.draft_id = NEW.source_draft_id
    AND r.revision = NEW.source_revision;

  IF authored IS NULL OR authored IS DISTINCT FROM NEW.document THEN
    RAISE EXCEPTION 'Release must be a frozen copy of the exact Studio revision';
  END IF;
  RETURN NEW;
END
$function$;
    $ddl$;
  END IF;
END
$sideworld_private_edit$;
