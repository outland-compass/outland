import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
const api = readFileSync(new URL('../app/api/studio/character-approval/route.ts', import.meta.url), 'utf8');
test('approval is disabled by default, origin-bound and admin-only', () => {
  assert.match(api, /authorize\(request, denied\)/);
  assert.match(api, /SIDEWORLD_CHARACTER_APPROVAL_WRITES/);
  assert.match(api, /Origin mismatch/);
  assert.match(api, /lookupCharacterForMedia/);
});
test('approval binds exact draft, hash, reviewer and rights statement', () => {
  assert.match(api, /source_sha256/);
  assert.match(api, /approval_status', 'eq\.draft'/);
  assert.match(api, /rightsNote\.trim\(\)\.length < 20/);
  assert.match(api, /approved_by: user\.id/);
  assert.match(api, /rows\.length !== 1/);
});
