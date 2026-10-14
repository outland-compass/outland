#!/usr/bin/env node
/**
 * SIDEWORLD Player V1 deployment PREFLIGHT ONLY. Never executes DDL or writes to DB.
 * Pinned to the exact additive SQL in OUTLAND Draft PR #70.
 *
 * Usage: node scripts/sideworld/player-runtime-preflight.mjs --check-file
 *        SUPABASE_PRODUCTION_DB_URL=... node scripts/sideworld/player-runtime-preflight.mjs --db-preflight
 */
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

export const PROD_PROJECT='huzcukdovavejejwohey';
export const MIGRATION_VERSION='20261014104136';
export const MIGRATION_NAME='sideworld_player_runtime_v1';
export const GIT_BLOB_SHA='8fcca2a8a0eec82f4dd899412e14848d279b9295';
export const RELATIVE_SQL='supabase/migrations/20261014104136_sideworld_player_runtime_v1.sql';
const SQL_URL=new URL('../../'+RELATIVE_SQL,import.meta.url);
const EXPECTED_SOURCE={
  'auth.users': ['af49f9057dbb2b7c7f6e9c29286876fd','73b85c58a04ce4cff541447ffa048314','786e53a33077b3a68f1ec248e238d18a'],
  'canon.quest_drafts': ['9a85b5c3dd0ad5fd38e8ba3ee9a81d5d','f1740f2c55b0a056228792424c2799cb','d41d8cd98f00b204e9800998ecf8427e'],
  'canon.quest_draft_revisions': ['426c3429fcfe25a3e5691e1a688a27a2','03b3d79f113b6f69750461fdbdf89be2','d41d8cd98f00b204e9800998ecf8427e'],
  'shared.user_roles': ['fd14ded17672839d4d75d12bf40df7cd','9e4917053b521be5e79d59e8d2cb2d1c','d41d8cd98f00b204e9800998ecf8427e']
};

export function blobSha(source) {
  const bytes=Buffer.from(source,'utf8');
  return createHash('sha1').update('blob '+bytes.length+'\0').update(bytes).digest('hex');
}
export function verifySql(source) {
  if(typeof source!=='string'||blobSha(source)!==GIT_BLOB_SHA) throw Error('STOP: Player migration SQL differs from audited Git blob');
  if((source.match(/\bcreate table\b/gi)||[]).length!==4 ||
     (source.match(/\bcreate function public\.sideworld_player_/gi)||[]).length!==8 ||
     /\b(drop|truncate)\s+(table|schema)\b/i.test(source)) throw Error('STOP: unexpected Player migration DDL');
  return {
    migration:MIGRATION_VERSION+'_'+MIGRATION_NAME,
    gitBlobSha:GIT_BLOB_SHA,
    sha256:createHash('sha256').update(source).digest('hex'),
    bytes:Buffer.byteLength(source)
  };
}

export function connectionEnv(dbUrl) {
  if(!dbUrl) throw Error('STOP: missing production DB URL (no connection attempted)');
  let u;try {u=new URL(dbUrl);}catch {throw Error('STOP: invalid production DB connection URL');}
  const direct=u.hostname===`db.${PROD_PROJECT}.supabase.co` && decodeURIComponent(u.username)==='postgres';
  const pooled=u.hostname.endsWith('.pooler.supabase.com') &&
    decodeURIComponent(u.username)===`postgres.${PROD_PROJECT}` &&
    (u.port===''||u.port==='5432');
  if(!['postgres:','postgresql:'].includes(u.protocol)||
     u.pathname!=='/postgres'||!u.password||!direct&&!pooled||
     (u.port!==''&&u.port!=='5432') ||
     (u.searchParams.has('sslmode')&&u.searchParams.get('sslmode')!=='require') ||
     u.hash) throw Error('STOP: unexpected database/project/mode; expected OUTLAND production direct or session-pooler 5432');
  return {
    PGHOST:u.hostname,PGPORT:u.port||'5432',PGUSER:decodeURIComponent(u.username),
    PGPASSWORD:decodeURIComponent(u.password),PGDATABASE:'postgres',
    PGSSLMODE:'require',
    PGOPTIONS:'-c default_transaction_read_only=on -c statement_timeout=10000'
  };
}

export const READ_ONLY_INVENTORY=`
WITH rels AS (
 SELECT c.oid,n.nspname||'.'||c.relname AS rel,c.relrowsecurity
 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE (n.nspname='canon' AND c.relname IN ('quest_drafts','quest_draft_revisions'))
    OR (n.nspname='shared' AND c.relname='user_roles')
    OR (n.nspname='auth' AND c.relname='users')
), fps AS (
 SELECT t.rel,t.relrowsecurity,
   (SELECT md5(COALESCE(string_agg(pg_get_constraintdef(c.oid), E'\\n' ORDER BY c.conname),'')) FROM pg_constraint c WHERE c.conrelid=t.oid) AS ch,
   (SELECT md5(COALESCE(string_agg(pg_get_indexdef(ix.indexrelid), E'\\n' ORDER BY ix.indexrelid::text),'')) FROM pg_index ix WHERE ix.indrelid=t.oid) AS ih,
   (SELECT md5(COALESCE(string_agg(pg_get_triggerdef(tr.oid), E'\\n' ORDER BY tr.tgname),'')) FROM pg_trigger tr WHERE tr.tgrelid=t.oid AND NOT tr.tgisinternal) AS th
 FROM rels t
)
SELECT json_build_object(
  'db',current_database(),'major',current_setting('server_version_num')::integer,
  'migrationCount',(SELECT count(*) FROM supabase_migrations.schema_migrations),
  'latestMigration',(SELECT version FROM supabase_migrations.schema_migrations ORDER BY version DESC LIMIT 1),
  'alreadyApplied',(SELECT count(*) FROM supabase_migrations.schema_migrations WHERE version='${MIGRATION_VERSION}' OR name='${MIGRATION_NAME}'),
  'playerObjects',(SELECT count(*) FROM pg_class c JOIN pg_namespace n ON c.relnamespace=n.oid WHERE (n.nspname='player' AND c.relkind IN ('r','p')) OR (n.nspname='canon' AND c.relname='quest_releases')),
  'playerFunctions',(SELECT count(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace=n.oid WHERE n.nspname='public' AND p.proname LIKE 'sideworld_player_%'),
  'source',COALESCE((SELECT json_agg(json_build_object('rel',rel,'rls',relrowsecurity,'constraints',ch,'indexes',ih,'triggers',th) ORDER BY rel) FROM fps),'[]'::json)
)::text;`;

export function verifyLiveInventory(x) {
  if(!x||x.db!=='postgres'||!Number.isInteger(x.major)||x.major<170000||x.major>=180000 ||
     x.migrationCount!==38||x.latestMigration!=='20261012151318'||
     x.alreadyApplied!==0||x.playerObjects!==0||x.playerFunctions!==0||
     !Array.isArray(x.source)||x.source.length!==4) throw Error('STOP: production database/migration preconditions changed');
  for(const row of x.source){
    const expected=EXPECTED_SOURCE[row.rel];
    if(!expected||row.rls!==true||
      row.constraints!==expected[0]||row.indexes!==expected[1]||row.triggers!==expected[2]) {
      throw Error('STOP: production source object dependencies changed');
    }
  }
  return { environment:'OUTLAND production',project:PROD_PROJECT,
    priorMigrations:x.migrationCount, latest:x.latestMigration,
    sourceTablesVerified:x.source.length, playerObjectsAbsent:true };
}
export function runReadOnlyInventory(connUrl) {
  const env=connectionEnv(connUrl);
  const p=spawnSync('psql',['-X','-qAt','-v','ON_ERROR_STOP=1','-c',READ_ONLY_INVENTORY],
     {env:{...process.env,...env},encoding:'utf8',timeout:20000,maxBuffer:150000,windowsHide:true});
  if(p.error||p.status!==0) throw Error('STOP: production read-only inventory unavailable (psql connection/query failed)');
  let json;try{json=JSON.parse(p.stdout.trim());}catch{throw Error('STOP: malformed read-only production response');}
  return verifyLiveInventory(json);
}
function main() {
  const mode=process.argv[2]??'--check-file';
  if(!['--check-file','--db-preflight'].includes(mode)||process.argv.length>3)
    throw Error('STOP: only --check-file and --db-preflight supported; NO database write mode');
  const sql=readFileSync(fileURLToPath(SQL_URL),'utf8');
  const file=verifySql(sql);
  if(mode==='--check-file'){console.log(JSON.stringify({mode:'OFFLINE_ONLY',...file},null,2));return;}
  const inventory=runReadOnlyInventory(process.env.SUPABASE_PRODUCTION_DB_URL);
  console.log(JSON.stringify({mode:'READ_ONLY_PRODUCTION_PREFLIGHT',sql:file,database:inventory,
    safeToApply:false,reason:'Separate explicit founder approval, backup custody and vetted version-preserving runner required.'},null,2));
}
if(process.argv[1]&&fileURLToPath(import.meta.url)===process.argv[1]){
  try{main();}catch(err){console.error(err instanceof Error?err.message:'STOP: preflight failed');process.exitCode=1;}
}
