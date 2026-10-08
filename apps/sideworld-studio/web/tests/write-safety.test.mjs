import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
const source = readFileSync(new URL('../app/api/studio/write/route.ts', import.meta.url), 'utf8');

test('cross-universe writes fail closed until ownership validation is implemented', () => {
  assert.match(source, /Studio writes temporarily disabled pending universe ownership validation/);
  assert.match(source, /status: 503/);
  const gate = source.indexOf('Studio writes temporarily disabled');
  const mutation = source.indexOf('const rpc = buildRpc(entity,');
  assert.ok(gate > 0 && mutation > gate);
});
