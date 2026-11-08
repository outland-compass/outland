-- Production function snapshot before private QA editable releases.
-- Rollback only; exact existing function body, no data changes.
CREATE OR REPLACE FUNCTION canon.sideworld_guard_release_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare authored jsonb;
begin
  if TG_OP='DELETE' then raise exception 'Quest release deletion is disabled'; end if;
  if TG_OP='UPDATE' then
    if new.id is distinct from old.id or
       new.source_draft_id is distinct from old.source_draft_id or
       new.source_revision is distinct from old.source_revision or
       new.document is distinct from old.document or
       new.engine_content_hash is distinct from old.engine_content_hash or
       new.created_by is distinct from old.created_by or
       new.created_at is distinct from old.created_at then
      raise exception 'Quest release content and source are immutable';
    end if;
    if (old.visibility='retired' and new.visibility <> 'retired')
       or (old.visibility='published' and new.visibility='private_qa') then
      raise exception 'Invalid release lifecycle transition';
    end if;
    new.updated_at:=now();
    return new;
  end if;
  select r.document into authored from canon.quest_draft_revisions r
  where r.draft_id=new.source_draft_id and r.revision=new.source_revision;
  if authored is null or authored is distinct from new.document then
    raise exception 'Release must be a frozen copy of the exact Studio revision';
  end if;
  return new;
end $function$;
