import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

test('Studio V0-C remains non-writing', async () => {
  const readme = await readFile(new URL('../README.md', import.meta.url), 'utf8');
  assert.match(readme, /no authoring writes/i);
});

test('Studio RPC reader stays server-only and keeps the service key private', async () => {
  const source = await readFile(new URL('../lib/studio/read-model.ts', import.meta.url), 'utf8');
  assert.match(source, /server-only/);
  assert.match(source, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.doesNotMatch(source, /NEXT_PUBLIC_/);
  assert.match(source, /STUDIO_DATA_SOURCE/);
});

test('fixture is still the default data source', async () => {
  const source = await readFile(new URL('../lib/studio/read-model.ts', import.meta.url), 'utf8');
  assert.match(source, /process\.env\.STUDIO_DATA_SOURCE \?\? 'fixture'/);
});

test('fixture marks itself as non-production canon', async () => {
  const source = await readFile(new URL('../lib/studio/fixture.ts', import.meta.url), 'utf8');
  assert.match(source, /Not production canon/);
  assert.match(source, /The Unbroken Line is an overarching mystery, not a series/);
});
