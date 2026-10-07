import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

test('Studio shell remains explicitly non-writing in V0-B', async () => {
  const readme = await readFile(new URL('../README.md', import.meta.url), 'utf8');
  assert.match(readme, /no database/i);
});

test('Canon Inspector uses the server-only read contract', async () => {
  const source = await readFile(new URL('../lib/studio/read-model.ts', import.meta.url), 'utf8');
  assert.match(source, /server-only/);
  assert.doesNotMatch(source, /service_role|SUPABASE_SERVICE/i);
});

test('fixture marks itself as non-production canon', async () => {
  const source = await readFile(new URL('../lib/studio/fixture.ts', import.meta.url), 'utf8');
  assert.match(source, /Not production canon/);
  assert.match(source, /The Unbroken Line is an overarching mystery, not a series/);
});
