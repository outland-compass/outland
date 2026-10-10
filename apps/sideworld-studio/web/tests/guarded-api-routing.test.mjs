import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const route = readFileSync(new URL('../app/api/studio/write/route.ts', import.meta.url), 'utf8');

test('write API is disabled by default and requires explicit flag', () => {
  assert.match(route, /SIDEWORLD_STUDIO_GUARDED_WRITES.*'enabled'/);
  assert.match(route, /status: 503/);
});
test('guarded writes require universe slug and route only through transactional RPC', () => {
  assert.match(route, /searchParams\.get\('universe'\)/);
  assert.match(route, /sideworld_studio_guarded_save_root/);
  assert.match(route, /sideworld_studio_guarded_save_canon/);
  assert.match(route, /p_universe_slug: selectedUniverse/);
  assert.match(route, /p_input: rpc\.body/);
});
test('shared geo and universe creation are denied even when flag enabled', () => {
  assert.match(route, /const rootEntities = \['world', 'theme', 'franchise'\]/);
  assert.match(route, /const canonEntities = \['series', 'character', 'faction', 'lore', 'rule'\]/);
  assert.match(route, /Entity is not supported by guarded writes/);
  assert.doesNotMatch(route, /callStudioRpc<string>\(rpc\.name/);
});
