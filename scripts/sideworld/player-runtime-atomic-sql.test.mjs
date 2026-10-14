import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {renderAtomicSql,ADVISORY_LOCK_KEY} from './player-runtime-atomic-sql.mjs';
import {GIT_BLOB_SHA,MIGRATION_VERSION} from './player-runtime-preflight.mjs';
const real=readFileSync(new URL('../../supabase/migrations/20261014104136_sideworld_player_runtime_v1.sql',import.meta.url),'utf8');

test('renders reviewed migration, explicit BEGIN/COMMIT, preflight lock and EXACT history version',()=>{
  const p=renderAtomicSql(real);
  assert.match(p,/^-- GENERATED, AUDITED SIDEWORLD PLAYER V1 TRANSACTION/);
  assert.match(p,new RegExp('Reviewed Git blob: '+GIT_BLOB_SHA));
  assert.match(p,new RegExp('pg_advisory_xact_lock\\('+ADVISORY_LOCK_KEY+'\\)'));
  assert.match(p,new RegExp("VALUES\\('"+MIGRATION_VERSION+"'"));
  assert.match(p,/BEGIN;/);assert.match(p,/COMMIT;\s*$/);
  assert.match(p,/ARRAY\[\$sideworld_player_sql_source\$/);
  assert.match(p,/sideworld_player_qa_revoke_v1/);
  assert.ok(p.indexOf('create table canon.quest_releases')<p.indexOf('INSERT INTO supabase_migrations.schema_migrations'));
  assert.ok(p.indexOf('INSERT INTO supabase_migrations.schema_migrations')<p.indexOf('END $sideworld_player_postflight$'));
  assert.ok(!p.includes('DROP SCHEMA'));
  assert.ok(!p.includes('TRUNCATE TABLE'));
});

test('renderer never bypasses source fingerprint or permits unexpected SQL markers',()=>{
  assert.throws(()=>renderAtomicSql(real+'\n'),/STOP/);
  assert.throws(()=>renderAtomicSql('DROP TABLE public.users'),/STOP/);
});

test('CLI only renders SQL for explicit external review, cannot connect or apply itself',()=>{
  const script=fileURLToPath(new URL('./player-runtime-atomic-sql.mjs',import.meta.url));
  assert.throws(()=>execFileSync(process.execPath,[script,'--apply'],{stdio:['ignore','pipe','pipe']}));
  const p=execFileSync(process.execPath,[script,'--render-for-review'],{encoding:'utf8'});
  assert.equal(p,renderAtomicSql(real));
  assert.match(p,/DO \$sideworld_player_postflight\$/);
});
