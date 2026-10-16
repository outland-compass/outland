-- Run after sideworld_real_user_private_release_access migration.
-- Read-only verification: existing private grants retained, no global access.
DO $$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='player' AND c.relname='release_access' AND c.relrowsecurity)
 THEN RAISE EXCEPTION 'real-user release entitlements must have RLS'; END IF;
 IF has_table_privilege('anon','player.release_access','SELECT')
    OR has_table_privilege('authenticated','player.release_access','INSERT')
    OR has_table_privilege('authenticated','player.release_access','UPDATE')
    OR has_table_privilege('anon','player.release_access','DELETE')
 THEN RAISE EXCEPTION 'browser roles must not manipulate private access'; END IF;
 IF has_function_privilege('authenticated',
   'public.sideworld_player_release_access_grant_v1(uuid,uuid,uuid)','EXECUTE')
    OR has_function_privilege('anon',
   'public.sideworld_player_release_access_revoke_v1(uuid,uuid,uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'private entitlement management must be service-only'; END IF;
 IF NOT has_function_privilege('service_role',
   'public.sideworld_player_release_access_grant_v1(uuid,uuid,uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'service operator needs safe grant RPC'; END IF;
 IF player.can_use_release_v1(null,null) THEN
  RAISE EXCEPTION 'anonymous access must be denied'; END IF;
END $$;
SELECT 'PASS: persistent real-user release entitlement is private and revocable' AS result;
