#!/usr/bin/env node
/**
 * Render an ATOMIC, version-preserving SQL transaction for independent review
 * and disposable-DB rehearsal. This program NEVER CONNECTS TO ANY DATABASE.
 *
 * No automatic production execution: the rendered plan requires an explicitly
 * approved operator-controlled psql execution path and verified restore evidence.
 */
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { verifySql, MIGRATION_VERSION, MIGRATION_NAME, RELATIVE_SQL, GIT_BLOB_SHA } from './player-runtime-preflight.mjs';

const location=new URL('../../'+RELATIVE_SQL,import.meta.url);
export const ADVISORY_LOCK_KEY=1202610141;

export function renderAtomicSql(sql) {
  const evidence=verifySql(sql);
  if(sql.includes('$sideworld_player_sql_source$') ||
     sql.includes('$sideworld_player_preflight$') ||
     sql.includes('$sideworld_player_postflight$')) {
    throw Error('STOP: SQL collides with transaction literal markers');
  }
  const contentTag='$sideworld_player_sql_source$';
  const output=`-- GENERATED, AUDITED SIDEWORLD PLAYER V1 TRANSACTION. NOT AUTHORIZATION.
-- Reviewed Git blob: ${GIT_BLOB_SHA}
-- SHA256: ${evidence.sha256}
-- DO NOT EXECUTE ON PRODUCTION UNTIL EXPLICIT FOUNDER APPROVAL.
BEGIN;
SET LOCAL statement_timeout = '90000ms';
SET LOCAL lock_timeout = '15000ms';
SELECT pg_advisory_xact_lock(${ADVISORY_LOCK_KEY});
DO $sideworld_player_preflight$
BEGIN
  IF current_database()<>'postgres' OR current_setting('server_version_num')::integer NOT BETWEEN 170000 AND 179999
    OR (SELECT count(*) FROM supabase_migrations.schema_migrations)<>38
    OR (SELECT max(version) FROM supabase_migrations.schema_migrations)<>'20261012151318'
    OR EXISTS(SELECT 1 FROM supabase_migrations.schema_migrations WHERE version='${MIGRATION_VERSION}' OR name='${MIGRATION_NAME}')
    OR to_regclass('canon.quest_releases') IS NOT NULL
    OR EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE n.nspname='player' AND c.relkind IN ('r','p'))
    OR EXISTS (SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname LIKE 'sideworld_player_%')
  THEN RAISE EXCEPTION 'SIDEWORLD PLAYER V1 STOP: migration baseline drift/collision'; END IF;
END $sideworld_player_preflight$;

${sql}

-- Supabase's migration history is updated in the SAME transaction as the DDL.
-- Never rewrite or delete existing history, including the 3 older timestamp differences.
INSERT INTO supabase_migrations.schema_migrations(version,name,statements,created_by)
VALUES('${MIGRATION_VERSION}','${MIGRATION_NAME}',
       ARRAY[${contentTag}${sql}${contentTag}]::text[],
       'sideworld-player-reviewed-runner-v1');

DO $sideworld_player_postflight$
BEGIN
  IF (SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version='${MIGRATION_VERSION}' AND name='${MIGRATION_NAME}')<>1
    OR (SELECT count(*) FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid
        WHERE (n.nspname='canon' AND c.relname='quest_releases' AND c.relkind='r')
          OR (n.nspname='player' AND c.relname IN ('qa_access','quest_runs','run_receipts') AND c.relkind='r'))<>4
    OR EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid
        WHERE ((n.nspname='canon' AND c.relname='quest_releases')
            OR (n.nspname='player' AND c.relname IN ('qa_access','quest_runs','run_receipts')))
          AND NOT c.relrowsecurity)
    OR (SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
        WHERE n.nspname='public' AND p.proname LIKE 'sideworld_player_%')<>8
    OR EXISTS(SELECT 1 FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid
        WHERE n.nspname='public' AND p.proname LIKE 'sideworld_player_%'
          AND (has_function_privilege('anon',p.oid,'EXECUTE')
            OR has_function_privilege('authenticated',p.oid,'EXECUTE')
            OR NOT has_function_privilege('service_role',p.oid,'EXECUTE')))
    OR (SELECT count(*) FROM canon.quest_releases)<>0
    OR (SELECT count(*) FROM player.qa_access)<>0
    OR (SELECT count(*) FROM player.quest_runs)<>0
    OR (SELECT count(*) FROM player.run_receipts)<>0
  THEN RAISE EXCEPTION 'SIDEWORLD PLAYER V1 STOP: postflight grants/schema/data mismatch'; END IF;
END $sideworld_player_postflight$;
COMMIT;
`;
  return output;
}

if (process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){
  if(process.argv.length!==3||process.argv[2]!=='--render-for-review'){
    console.error('STOP: only --render-for-review supported; no database connection/execute mode');
    process.exitCode=1;
  }else {
    try{process.stdout.write(renderAtomicSql(readFileSync(location,'utf8')));}
    catch(e){console.error(e instanceof Error?e.message:'STOP');process.exitCode=1;}
  }
}
