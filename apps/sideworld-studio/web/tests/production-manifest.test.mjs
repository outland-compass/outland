import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const manifest = readFileSync(new URL('../lib/studio/production-manifest.ts', import.meta.url), 'utf8');
const page = readFileSync(new URL('../app/studio/production/page.tsx', import.meta.url), 'utf8');

test('production manifest enforces canonical universe and city boundaries', () => {
  assert.match(manifest, /canon\.franchise\.universeId !== canon\.universe\.id/);
  assert.match(manifest, /canon\.cities\.some\(item => item\.id === city\.id\)/);
  assert.match(manifest, /item\.cityId === city\.id/);
});

test('production manifest only includes verified public locations and supported facts', () => {
  assert.match(manifest, /item\.verificationStatus === 'verified' && item\.publicAccess === true/);
  assert.match(manifest, /link\.supportType === 'supports'/);
  assert.match(manifest, /supportedFactIds\.has\(item\.id\)/);
  assert.match(manifest, /diagnostics\.length === 0/);
});

test('Studio previews the manifest without invoking generation or mutation', () => {
  assert.match(page, /buildProductionInputManifestV1\(context, knowledge\)/);
  assert.match(page, /Inspect manifest JSON/);
  assert.match(page, /manifest\.diagnostics\.map|manifest\?\.diagnostics\.map/);
  assert.doesNotMatch(page, /callStudioRpc|\.insert\(|\.update\(/);
});
