-- SIDEWORLD Player V1: verify role-based denial in an isolated Supabase CI DB.
-- No user data, no persistent changes. Requires the proposed migration.
begin;
set local role anon;
do $security$
begin
  if current_user <> 'anon' then raise exception 'anon role not active'; end if;
  begin
    perform id from canon.quest_releases limit 1;
    raise exception 'anon unexpectedly read quest releases';
  exception when insufficient_privilege then null;
  end;
  begin
    perform id from player.quest_runs limit 1;
    raise exception 'anon unexpectedly read private run history';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.sideworld_player_release_get_v1(
      '00000000-0000-4000-8000-000000000001'::uuid,
      '00000000-0000-4000-8000-000000000002'::uuid);
    raise exception 'anon unexpectedly called privileged release RPC';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.sideworld_player_run_apply_v1(
      '00000000-0000-4000-8000-000000000001'::uuid,
      '00000000-0000-4000-8000-000000000002'::uuid,
      '00000000-0000-4000-8000-000000000003'::uuid,
      repeat('b',64),0,'{}'::jsonb);
    raise exception 'anon unexpectedly called privileged mutation RPC';
  exception when insufficient_privilege then null;
  end;
end
$security$;
rollback;

begin;
set local role authenticated;
do $security$
begin
  if current_user <> 'authenticated' then raise exception 'authenticated role not active'; end if;
  begin
    perform id from canon.quest_releases limit 1;
    raise exception 'authenticated unexpectedly read quest releases';
  exception when insufficient_privilege then null;
  end;
  begin
    perform id from player.quest_runs limit 1;
    raise exception 'authenticated unexpectedly read private run history';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.sideworld_player_release_get_v1(
      '00000000-0000-4000-8000-000000000001'::uuid,
      '00000000-0000-4000-8000-000000000002'::uuid);
    raise exception 'authenticated unexpectedly called privileged release RPC';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.sideworld_player_run_start_v1(
      '00000000-0000-4000-8000-000000000001'::uuid,
      '00000000-0000-4000-8000-000000000002'::uuid,
      '00000000-0000-4000-8000-000000000003'::uuid,
      '{}'::jsonb);
    raise exception 'authenticated unexpectedly called privileged start RPC';
  exception when insufficient_privilege then null;
  end;
end
$security$;
rollback;
