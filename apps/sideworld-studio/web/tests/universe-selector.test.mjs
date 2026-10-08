import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
const read = p => readFileSync(new URL(p, import.meta.url), 'utf8');

test('catalog reads canonical universes through service-role RPC', () => {
  const source = read('../lib/studio/universes.ts');
  assert.match(source, /sideworld_studio_list_universes/);
  assert.match(source, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.match(source, /cache: 'no-store'/);
});
test('runtime read model resolves universe dynamically', () => {
  const source = read('../lib/studio/read-model.ts');
  assert.match(source, /resolveStudioUniverse/);
  assert.doesNotMatch(source, /STUDIO_UNIVERSE_SLUG/);
  assert.match(source, /p_universe_slug: universeSlug/);
});
test('selector persists selection and clears cross-universe context', () => {
  const source = read('../app/studio/universe-selector.tsx');
  assert.match(source, /localStorage.setItem/);
  assert.match(source, /p.delete\(key\)/);
});
test('catalog RPC is restricted to service_role', () => {
  const source = read('../../../../supabase/migrations/202610080005_sideworld_studio_universe_catalog.sql');
  assert.match(source, /from universe.universes/);
  assert.match(source, /revoke all/);
  assert.match(source, /grant execute.*service_role/);
});
