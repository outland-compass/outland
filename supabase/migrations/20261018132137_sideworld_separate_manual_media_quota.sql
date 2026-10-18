-- SIDEWORLD Quest Media: split the free manual import quota from paid AI jobs.
-- REVIEW ONLY: production execution requires explicit founder approval and verified
-- backup / isolated restore. No data backfill, changes, deletes, or new tables.
--
-- Replaces the existing service-only reservation RPC with the same signature.
-- The 20/rolling-24h AI-generation cap and USD 5 daily budget are retained.
-- Founder-authorized manual imports have a separate 120/rolling-24h cap and MUST
-- have zero reserved cost. SHA-256, storage, approval and immutable release
-- binding guards remain in their original service-only RPCs.
--
-- Safe rollback: restore the complete RPC body from
-- 20261015210824_sideworld_quest_visual_production_v1.sql (the original
-- 20/24h combined cap). Do not drop any jobs/assets/bindings or revoke existing
-- service_role grants; restoring that function is backward compatible.

create or replace function public.sideworld_quest_visual_reserve(
 p_actor uuid,p_draft uuid,p_revision integer,p_brief text,p_request uuid,
 p_provider text,p_model text,p_max_cost_usd numeric
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 v_doc jsonb;
 v_found canon.quest_visual_jobs;
 v_daily numeric;
begin
 if not exists(
   select 1 from shared.user_roles
   where user_id=p_actor and role::text in ('OWNER','ADMIN')
 ) then raise exception 'Admin required'; end if;
 if p_request is null or p_provider not in ('openai','manual') or
    length(p_model) not between 1 and 120 or
    p_max_cost_usd is null or p_max_cost_usd < 0 or p_max_cost_usd > 1
 then raise exception 'Invalid generation limits'; end if;
 -- A zero-cost import must not be allowed to reserve a paid AI budget.
 if p_provider='manual' and p_max_cost_usd<>0
 then raise exception 'Manual media import must reserve zero cost'; end if;

 perform pg_advisory_xact_lock(hashtextextended(p_actor::text,7));
 select document into v_doc from canon.quest_draft_revisions
 where draft_id=p_draft and revision=p_revision;
 if v_doc is null or not exists(
    select 1 from canon.quest_drafts where id=p_draft and status='draft'
 ) or not exists(
    select 1 from jsonb_array_elements(coalesce(v_doc->'visualBriefs','[]'::jsonb)) b
    where b->>'id'=p_brief
 ) then raise exception 'Unknown draft/revision/brief'; end if;

 -- Idempotency check must occur before rate limits. Repeated requests to finish
 -- the same job do not consume a second reservation.
 select * into v_found from canon.quest_visual_jobs
 where actor_id=p_actor and request_key=p_request;
 if found then
   if v_found.draft_id<>p_draft or v_found.revision<>p_revision or
      v_found.brief_id<>p_brief or v_found.provider<>p_provider or
      v_found.model<>p_model
   then raise exception 'Idempotency key reused for different job'; end if;
   return jsonb_build_object('id',v_found.id,'status',v_found.status,'created',false);
 end if;

 -- Separate bounded throughput for founder-approved manual ZIP imports.
 if p_provider='manual' then
   if (select count(*) from canon.quest_visual_jobs
       where actor_id=p_actor and provider='manual'
         and created_at>now()-interval '24 hours')>=120
   then raise exception 'Daily manual media import cap reached'; end if;
 else
   -- This paid-provider ceiling is unchanged in absolute size, but manual
   -- no-cost imports do not consume it.
   if (select count(*) from canon.quest_visual_jobs
       where actor_id=p_actor and provider='openai'
         and created_at>now()-interval '24 hours')>=20
   then raise exception 'Daily AI generation job cap reached'; end if;
   select coalesce(sum(greatest(max_cost_usd,coalesce(actual_cost_usd,0))),0)
     into v_daily
   from canon.quest_visual_jobs
   where actor_id=p_actor and provider='openai'
     and created_at>now()-interval '24 hours' and status<>'failed';
   if v_daily+p_max_cost_usd>5
   then raise exception 'Daily generation budget reached'; end if;
 end if;

 insert into canon.quest_visual_jobs(
   draft_id,revision,brief_id,actor_id,request_key,
   provider,model,max_cost_usd
 ) values(
   p_draft,p_revision,p_brief,p_actor,p_request,
   p_provider,p_model,p_max_cost_usd
 ) returning * into v_found;
 return jsonb_build_object('id',v_found.id,'status',v_found.status,'created',true);
end $$;

-- Reaffirm the existing service-only boundary after CREATE OR REPLACE.
revoke all on function public.sideworld_quest_visual_reserve(
 uuid,uuid,integer,text,uuid,text,text,numeric
) from public,anon,authenticated;
grant execute on function public.sideworld_quest_visual_reserve(
 uuid,uuid,integer,text,uuid,text,text,numeric
) to service_role;
