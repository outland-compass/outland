import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

test('write API checks actual request bytes and rejects null or array payloads', () => {
  const source = readFileSync(new URL('../app/api/studio/write/route.ts', import.meta.url), 'utf8');
  assert.match(source, /await request\.text\(\)/);
  assert.match(source, /TextEncoder\(\)\.encode\(raw\)\.byteLength > 24_000/);
  assert.match(source, /JSON\.parse\(raw\)/);
  assert.match(source, /!body \|\| typeof body !== 'object' \|\| Array\.isArray\(body\)/);
  assert.match(source, /SIDEWORLD_STUDIO_GUARDED_WRITES !== 'enabled'/);
  assert.match(source, /request\.headers\.get\('origin'\)/);
});
