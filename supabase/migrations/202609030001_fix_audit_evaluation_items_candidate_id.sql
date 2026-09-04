-- 202609030001_fix_audit_evaluation_items_candidate_id.sql
-- Fix: land.evaluation_items has no candidate_id column, so audit_compass_change()
-- always wrote shared.activities rows for it with candidate_id = NULL. A NULL FK
-- value never participates in ON DELETE CASCADE, so those rows never got cleaned
-- up when the candidate/evaluation was deleted, and their actor_id could then block
-- deleting the associated auth user. This migration:
--   1. Teaches audit_compass_change() to resolve candidate_id for evaluation_items
--      via evaluation_items.evaluation_id -> land.evaluations.candidate_id.
--   2. Backfills existing NULL candidate_id rows for still-existing evaluation_items.
-- All other audited entities (candidates, candidate_economics, candidate_gates,
-- dd_items, decisions, evaluations) already carry a direct candidate_id column and
-- are unaffected by this change.

create or replace function public.audit_compass_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_candidate_id uuid;
  v_entity_id text;
begin
  v_entity_id := coalesce(
    case when tg_op <> 'DELETE' then to_jsonb(new)->>'id' end,
    case when tg_op <> 'INSERT' then to_jsonb(old)->>'id' end
  );

  v_candidate_id := coalesce(
    case when tg_op <> 'DELETE' then nullif(to_jsonb(new)->>'candidate_id','')::uuid end,
    case when tg_op <> 'INSERT' then nullif(to_jsonb(old)->>'candidate_id','')::uuid end,
    case when tg_table_name = 'candidates' and tg_op <> 'DELETE' then new.id else null end,
    case when tg_table_name = 'candidates' and tg_op <> 'INSERT' then old.id else null end
  );

  -- evaluation_items carries no candidate_id of its own; derive it through its
  -- parent evaluation so its audit rows cascade-delete like every other entity.
  if v_candidate_id is null and tg_table_name = 'evaluation_items' then
    select e.candidate_id into v_candidate_id
    from land.evaluations e
    where e.id = coalesce(
      case when tg_op <> 'DELETE' then nullif(to_jsonb(new)->>'evaluation_id','')::uuid end,
      case when tg_op <> 'INSERT' then nullif(to_jsonb(old)->>'evaluation_id','')::uuid end
    );
  end if;

  insert into shared.activities(
    candidate_id, entity_type, entity_id, action, actor_id, old_data, new_data
  )
  values (
    v_candidate_id,
    tg_table_name,
    v_entity_id,
    tg_op,
    auth.uid(),
    case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) else null end,
    case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) else null end
  );

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

-- Backfill: only fill in the previously-missing candidate_id for existing
-- evaluation_items audit rows whose evaluation_item still exists. Never touches
-- old_data/new_data or any other recorded audit content, and never deletes rows.
update shared.activities a
set candidate_id = e.candidate_id
from land.evaluation_items ei
join land.evaluations e on e.id = ei.evaluation_id
where a.entity_type = 'evaluation_items'
  and a.candidate_id is null
  and a.entity_id = ei.id::text;
