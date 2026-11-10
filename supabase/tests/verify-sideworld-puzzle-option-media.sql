-- Read-only, disposable database integrity checks for SIDEWORLD puzzle-option media V1.
DO $test$
BEGIN
 IF to_regclass('canon.quest_puzzle_option_media') IS NULL THEN
  RAISE EXCEPTION 'Missing canonical puzzle-option binding table';
 END IF;
 IF NOT EXISTS (
   SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname='canon' AND c.relname='quest_puzzle_option_media' AND c.relrowsecurity
 ) THEN RAISE EXCEPTION 'Puzzle-option table must enforce RLS'; END IF;
 IF EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='canon' AND
     tablename='quest_puzzle_option_media') THEN
   RAISE EXCEPTION 'No client-facing puzzle media policies permitted';
 END IF;
 IF has_table_privilege('anon','canon.quest_puzzle_option_media','SELECT') OR
    has_table_privilege('authenticated','canon.quest_puzzle_option_media','SELECT') OR
    has_table_privilege('anon','canon.quest_puzzle_option_media','INSERT') OR
    has_table_privilege('authenticated','canon.quest_puzzle_option_media','INSERT') THEN
    RAISE EXCEPTION 'Direct browser puzzle media table privileges detected';
 END IF;
 IF has_function_privilege('anon','public.sideworld_quest_puzzle_option_media_bind_v1(uuid,uuid,text,text,text,uuid)','EXECUTE') OR
    has_function_privilege('authenticated','public.sideworld_quest_puzzle_option_media_bind_v1(uuid,uuid,text,text,text,uuid)','EXECUTE') OR
    has_function_privilege('anon','public.sideworld_quest_puzzle_option_media_for_release_v1(uuid,text,text)','EXECUTE') OR
    has_function_privilege('authenticated','public.sideworld_quest_puzzle_option_media_for_release_v1(uuid,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'Puzzle media RPCs must not be browser callable';
 END IF;
 IF NOT has_function_privilege('service_role','public.sideworld_quest_puzzle_option_media_bind_v1(uuid,uuid,text,text,text,uuid)','EXECUTE') OR
    NOT has_function_privilege('service_role','public.sideworld_quest_puzzle_option_media_for_release_v1(uuid,text,text)','EXECUTE') THEN
    RAISE EXCEPTION 'Missing service role puzzle media access';
 END IF;
 IF (SELECT count(*) FROM canon.quest_puzzle_option_media)<>0 THEN
   RAISE EXCEPTION 'Migration created option mappings unexpectedly';
 END IF;
 IF (SELECT count(*) FROM canon.quest_visual_bindings)<>0 THEN
   RAISE EXCEPTION 'Migration changed legacy visual bindings';
 END IF;
END
$test$;
SELECT 'PASS: private option media records, functions and client denial' as result;
