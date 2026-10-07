import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

test('Studio access uses a signed server-only session', async () => {
  const source = await readFile(new URL('../lib/session.ts', import.meta.url), 'utf8');
  assert.match(source, /STUDIO_SESSION_SECRET/);
  assert.match(source, /timingSafeEqual/);
  assert.doesNotMatch(source, /NEXT_PUBLIC_/);
});

test('Studio authoring API verifies the private session', async () => {
  const source = await readFile(new URL('../app/api/studio/write/route.ts', import.meta.url), 'utf8');
  assert.match(source, /verifyStudioSession/);
  assert.match(source, /sideworld_studio_save_universe/);
  assert.match(source, /sideworld_studio_save_canon_rule/);
  assert.match(source, /sideworld_studio_save_world/);
  assert.match(source, /sideworld_studio_save_city/);
  assert.match(source, /sideworld_studio_save_character/);
});

test('Studio RPC client keeps the service key server-only', async () => {
  const source = await readFile(new URL('../lib/studio/rpc.ts', import.meta.url), 'utf8');
  assert.match(source, /server-only/);
  assert.match(source, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.doesNotMatch(source, /NEXT_PUBLIC_/);
});

test('fixture is still the default read source', async () => {
  const source = await readFile(new URL('../lib/studio/read-model.ts', import.meta.url), 'utf8');
  assert.match(source, /process\.env\.STUDIO_DATA_SOURCE \?\? 'fixture'/);
});

test('fixture preserves the initial narrative structure', async () => {
  const source = await readFile(new URL('../lib/studio/fixture.ts', import.meta.url), 'utf8');
  assert.match(source, /The Lost Cartographers/);
  assert.match(source, /Placeholder only/);
  assert.doesNotMatch(source, /id: 'u-beyond-atlas'/);
  assert.match(source, /The Unbroken Line is an overarching mystery, not a series/);
});
