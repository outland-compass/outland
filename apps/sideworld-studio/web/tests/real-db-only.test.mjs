import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const source = readFileSync(new URL('../lib/studio/read-model.ts', import.meta.url), 'utf8');

test('Studio runtime reads from Supabase without fixture fallback', () => {
  assert.match(source, /return readFromSupabase\(universeSlug\);/);
  assert.doesNotMatch(source, /studioReadContractFixture|STUDIO_DATA_SOURCE|structuredClone/);
});

test('Studio runtime requires backend credentials and canonical universe', () => {
  for (const key of ['SUPABASE_URL', 'SUPABASE_SERVICE_ROLE_KEY']) {
    assert.ok(source.includes(key), `Missing required environment variable: ${key}`);
  }
  assert.match(source, /resolveStudioUniverse/);
  assert.match(source, /if \(!model\.universe\)/);
});
