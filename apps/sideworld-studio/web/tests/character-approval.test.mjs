import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
const api = readFileSync(new URL('../app/api/studio/character-approval/route.ts', import.meta.url), 'utf8');
test('approval is disabled by default, origin-bound and admin-only', () => {
  assert.match(api, /authorize\(request, denied\)/);
  assert.match(api, /SIDEWORLD_CHARACTER_APPROVAL_WRITES/);
  assert.match(api, /Origin mismatch/);
  assert.match(api, /sideworld_character_media_approve/);
});
test('approval binds exact draft, hash, reviewer and rights statement', () => {
  assert.match(api, /source_sha256/);
  assert.match(api, /approval_status', 'eq\.draft'/);
  assert.match(api, /rightsNote\.trim\(\)\.length < 20/);
  assert.match(api, /approved_by: user\.id/);
  assert.match(api, /rows\.length !== 1/);
});

const gallery = readFileSync(new URL('../app/studio/characters/character-gallery.tsx', import.meta.url), 'utf8');
test('gallery approval requires explicit confirmation, rights note and exact asset hash', () => {
  assert.match(gallery, /window\.confirm/);
  assert.match(gallery, /rightsNote\.length < 20/);
  assert.match(gallery, /expectedSha256: asset\.source_sha256/);
  assert.match(gallery, /approvingId !== null/);
});
test('server rejects oversized payload and non-portrait asset role', () => {
  assert.match(api, /rawBody\.length > 4096/);
  assert.match(api, /asset_role', 'eq\.canonical_portrait'/);
});
