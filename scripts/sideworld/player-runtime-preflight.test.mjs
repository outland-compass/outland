import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  PROD_PROJECT,MIGRATION_VERSION,MIGRATION_NAME,GIT_BLOB_SHA,
  blobSha,verifySql,connectionEnv,verifyLiveInventory
} from './player-runtime-preflight.mjs';
const migration=new URL('../../supabase/migrations/20261014104136_sideworld_player_runtime_v1.sql',import.meta.url);
const real=readFileSync(migration,'utf8');
const fingerprints=[
 ['auth.users','af49f9057dbb2b7c7f6e9c29286876fd','73b85c58a04ce4cff541447ffa048314','786e53a33077b3a68f1ec248e238d18a'],
 ['canon.quest_draft_revisions','426c3429fcfe25a3e5691e1a688a27a2','03b3d79f113b6f69750461fdbdf89be2','d41d8cd98f00b204e9800998ecf8427e'],
 ['canon.quest_drafts','9a85b5c3dd0ad5fd38e8ba3ee9a81d5d','f1740f2c55b0a056228792424c2799cb','d41d8cd98f00b204e9800998ecf8427e'],
 ['shared.user_roles','fd14ded17672839d4d75d12bf40df7cd','9e4917053b521be5e79d59e8d2cb2d1c','d41d8cd98f00b204e9800998ecf8427e']
];
const validInventory=()=>({
  db:'postgres',major:170007,migrationCount:38,latestMigration:'20261012151318',
  alreadyApplied:0,playerObjects:0,playerFunctions:0,
  source:fingerprints.map(([rel,constraints,indexes,triggers])=>
    ({rel,rls:true,constraints,indexes,triggers}))
});
test('exact live PR #70 SQL is pinned by git blob SHA and has a stable SHA256',()=>{
  assert.equal(blobSha(real),GIT_BLOB_SHA);
  assert.equal(verifySql(real).migration,MIGRATION_VERSION+'_'+MIGRATION_NAME);
  assert.match(verifySql(real).sha256,/^[0-9a-f]{64}$/);
});
test('changed SQL, whitespace and appended destructive migration are rejected',()=>{
  for(const candidate of [real+' ',real.replace('create table canon.quest_releases','drop table canon.quest_releases'),
    real.replace('grant execute','grant all')])
    assert.throws(()=>verifySql(candidate),/STOP/);
});
test('production connection URI validation checks project and session pooler and never echoes passwords',()=>{
  const raw='postgresql://postgres:private-password@db.'+PROD_PROJECT+'.supabase.co:5432/postgres?sslmode=require';
  const env=connectionEnv(raw);
  assert.equal(env.PGUSER,'postgres');
  assert.equal(env.PGSSLMODE,'require');
  assert.match(env.PGOPTIONS,/read_only=on/);
  assert.equal(env.PGPASSWORD,'private-password');
  const pool='postgresql://postgres.'+PROD_PROJECT+':private-password@aws-0-eu-central-1.pooler.supabase.com:5432/postgres';
  assert.equal(connectionEnv(pool).PGUSER,'postgres.'+PROD_PROJECT);
  const invalid=[
    raw.replace(PROD_PROJECT,'clgpxvyflycudzhdzjlv'),
    raw.replace('db.'+PROD_PROJECT+'.supabase.co','attacker.supabase.co'),
    raw.replace('postgres:private-password','service_role:private-password'),
    raw.replace(':5432/postgres',':6543/postgres'),
    raw.replace('sslmode=require','sslmode=disable'),
    'not-a-url',''
  ];
  for(const value of invalid) assert.throws(()=>connectionEnv(value),/STOP/);
});
test('production dependency ledger and source fingerprints must exactly match verified evidence',()=>{
  assert.equal(verifyLiveInventory(validInventory()).sourceTablesVerified,4);
  for(const changed of [
    {migrationCount:39},{latestMigration:'20261014104136'},{alreadyApplied:1},
    {playerObjects:4},{playerFunctions:8},{major:160000},{db:'wrong'}
  ])assert.throws(()=>verifyLiveInventory({...validInventory(),...changed}),/STOP/);
  const x=validInventory();x.source[2].indexes='00000000000000000000000000000000';
  assert.throws(()=>verifyLiveInventory(x),/STOP/);
});
test('CLI has no apply mode, even with valid file and environment',()=>{
  const script=fileURLToPath(new URL('./player-runtime-preflight.mjs',import.meta.url));
  assert.throws(()=>execFileSync(process.execPath,[script,'--apply'],{encoding:'utf8',stdio:['ignore','pipe','pipe']}));
  const output=JSON.parse(execFileSync(process.execPath,[script,'--check-file'],{encoding:'utf8'}));
  assert.equal(output.mode,'OFFLINE_ONLY');
  assert.equal(output.gitBlobSha,GIT_BLOB_SHA);
});
