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

test('write forms are hidden while write gate is active', () => {
  const canon = readFileSync(new URL('../app/studio/canon/page.tsx', import.meta.url), 'utf8');
  const city = readFileSync(new URL('../app/studio/city/page.tsx', import.meta.url), 'utf8');
  assert.doesNotMatch(canon, /<CanonBootstrapEditor/);
  assert.doesNotMatch(city, /<CityKnowledgeEditor/);
  assert.match(canon, /READ-ONLY/);
});
