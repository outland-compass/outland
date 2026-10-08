import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
const api = readFileSync(new URL('../app/api/studio/character-approval/route.ts', import.meta.url), 'utf8');
const ui = readFileSync(new URL('../app/studio/characters/character-gallery.tsx', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../../../../supabase/migrations/20261008235902_sideworld_character_media_rpc_v1.sql', import.meta.url), 'utf8');
test('approval is disabled by default, origin-bound and admin-only', () => {
  assert.match(api, /authorize\(request, denied\)/);
  assert.match(api, /SIDEWORLD_CHARACTER_APPROVAL_WRITES/);
  assert.match(api, /Origin mismatch/);
  assert.match(api, /sideworld_character_media_approve/);
});
test('approval binds exact draft, hash, reviewer and rights statement', () => {
  assert.match(api, /p_expected_sha256: expectedSha256/);
  assert.match(api, /rightsNote\.trim\(\)\.length < 20/);
  assert.match(api, /p_reviewer_id: user\.id/);
  assert.match(api, /result\.json\(\) !== true/);
  assert.match(sql, /a\.approval_status = 'draft'/);
  assert.match(sql, /a\.asset_role = 'canonical_portrait'/);
  assert.match(sql, /grant execute on function public\.sideworld_character_media_approve/);
});
test('gallery requires explicit confirmation, justification and exact hash', () => {
  assert.match(ui, /window\.confirm/);
  assert.match(ui, /rightsNote\.length < 20/);
  assert.match(ui, /expectedSha256: asset\.source_sha256/);
  assert.match(ui, /approvingId !== null/);
  assert.match(api, /rawBody\.length > 4096/);
});
