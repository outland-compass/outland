-- OPTIONAL MANUAL ROLLBACK — never automatic after new multiple approvals.
-- Will refuse to reimpose uniqueness if more than one approved asset exists
-- in any (draft, revision, brief), preserving all content and statuses.
do $rollback_guard$
begin
 if exists (
   select 1 from canon.quest_visual_assets
    where approval_status='approved'
    group by draft_id,revision,brief_id
    having count(*)>1
 ) then raise exception 'Rollback unsafe: multi-image approvals already exist'; end if;
end $rollback_guard$;
create unique index quest_visual_one_approved_per_brief
 on canon.quest_visual_assets(draft_id,revision,brief_id)
 where approval_status='approved';
