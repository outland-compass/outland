import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const api = readFileSync(new URL('../app/api/studio/character-media/route.ts', import.meta.url), 'utf8');
const storage = readFileSync(new URL('../lib/studio/character-media-storage.ts', import.meta.url), 'utf8');

test('character upload is owner-authenticated, origin checked, and disabled by default', () => {
  assert.match(api, /authorize\(request, response\)/);
  assert.match(api, /request\.headers\.get\('origin'\)/);
  assert.match(api, /SIDEWORLD_CHARACTER_MEDIA_WRITES !== 'enabled'/);
});
test('original is hash checked and bounded before storage', () => {
  assert.match(api, /MAX_BYTES = 10 \* 1024 \* 1024/);
  assert.match(api, /createHash\('sha256'\)/);
  assert.match(api, /hash !== expectedHash/);
  assert.match(storage, /'x-upsert': 'false'/);
  assert.match(storage, /AbortSignal\.timeout/);
});
test('canonical universe scope, draft-only registry, cleanup, private storage', () => {
  assert.match(api, /lookupCharacterForMedia\(characterId, universe\)/);
  assert.match(api, /deleteUnregisteredCharacterOriginal\(stored\.path\)/);
  assert.match(storage, /approval_status: 'draft'/);
  assert.match(storage, /sideworld-character-media/);
  assert.doesNotMatch(storage, /getPublicUrl|createSignedUrl/);
});

test('private storage bytes are read back and hash verified before registration', () => {
  assert.match(storage, /object\/authenticated\/\$\{BUCKET\}/);
  assert.match(storage, /Private media readback SHA-256 mismatch/);
  assert.match(api, /await verifyStoredCharacterOriginal\(stored\.path, hash\)/);
  assert.match(api, /verified\.byteLength !== bytes\.byteLength/);
});
