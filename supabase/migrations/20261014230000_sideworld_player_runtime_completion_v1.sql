-- SIDEWORLD Player V1 completion persistence, additive and opt-in.
-- Requires production-applied Player runtime 20261014104136 and operator audit 20261014150000.
-- DO NOT enable the Player V2 adapter before this migration has been applied and verified.
-- Zero seeded rows; no existing data or RPC signature modified.
--
-- Only the trusted Player server knows whether deterministic engine.view(nextProgress)
-- is at stage='complete'. The database cannot infer that from bare event counts.
-- This service-role-only V2 wrapper applies progress + terminal status in the SAME
-- PostgreSQL transaction by invoking the already-reviewed V1 locked CAS/receipt RPC.
-- Existing V1 callers and previously persisted runs remain backwards compatible.

create function public.sideworld_player_run_apply_v2(
  p_actor uuid,p_run_id uuid,p_request_id uuid,p_fingerprint text,
  p_expected_sequence integer,p_next_progress jsonb,p_is_terminal boolean
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
  outcome jsonb;
  updated_rows integer;
begin
  if p_is_terminal is null then
    return jsonb_build_object('kind','invalid');
  end if;

  outcome := public.sideworld_player_run_apply_v1(
    p_actor,p_run_id,p_request_id,p_fingerprint,p_expected_sequence,p_next_progress
  );

  -- V1 locks the actor-scoped run, validates its canonical content binding,
  -- enforces entitlement and CAS, and creates the idempotency receipt.
  -- Do not mutate status for rejected, stale, or repeated operations.
  if outcome->>'kind' <> 'saved' or not p_is_terminal then
    return outcome;
  end if;

  update player.quest_runs
     set status='completed'
   where id=p_run_id and actor_id=p_actor
     and status='in_progress'
     and sequence=p_expected_sequence+1
     and progress=p_next_progress;
  get diagnostics updated_rows = row_count;
  if updated_rows <> 1 then
    -- Fail closed, rolling back the V1 progress and receipt atomically.
    raise exception 'SIDEWORLD terminal transition consistency failure';
  end if;

  return jsonb_set(outcome,'{status}',to_jsonb('completed'::text));
end $$;

-- Never rely on PostgreSQL default PUBLIC function EXECUTE.
revoke all on function public.sideworld_player_run_apply_v2(
  uuid,uuid,uuid,text,integer,jsonb,boolean
) from public,anon,authenticated,service_role;
grant execute on function public.sideworld_player_run_apply_v2(
  uuid,uuid,uuid,text,integer,jsonb,boolean
) to service_role;

comment on function public.sideworld_player_run_apply_v2(
  uuid,uuid,uuid,text,integer,jsonb,boolean
) is 'Privileged, opt-in atomic Player terminal-status wrapper over V1 CAS. p_is_terminal is supplied only after trusted engine validation; never accept it from client JSON.';

-- Rollback plan (only after disabling the Player V2 completion feature flag):
--   REVOKE ALL ON FUNCTION public.sideworld_player_run_apply_v2(
--     uuid,uuid,uuid,text,integer,jsonb,boolean) FROM service_role;
--   DROP FUNCTION public.sideworld_player_run_apply_v2(
--     uuid,uuid,uuid,text,integer,jsonb,boolean);
-- Keep all quest_runs, status values, receipts, QA evidence and migration history.
-- Do NOT replay older migration(s), and do NOT revert completed runs to in_progress.
