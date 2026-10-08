import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../lib/studio/character-visual-identity.ts', import.meta.url), 'utf8');
test('approved visual identity requires canon approval and a unique canonical portrait', () => {
  assert.match(source, /character\.canonStatus !== 'approved'/);
  assert.match(source, /portraits\.length !== 1/);
  assert.match(source, /approvedBy/);
  assert.match(source, /rightsNote/);
  assert.match(source, /contentHash/);
});
test('quest appearance pins version and only approved assets', () => {
  assert.match(source, /visualVersion: identity\.visualVersion/);
  assert.match(source, /canonicalPortraitAssetId: portrait\.assetId/);
  assert.match(source, /sceneAssetIds\.some\(id => !approvedAssetIds\.has\(id\)\)/);
});
test('contract has no persistence or provider calls', () => {
  assert.doesNotMatch(source, /fetch\(|process\.env|callStudioRpc|\.insert\(|\.update\(/);
});
