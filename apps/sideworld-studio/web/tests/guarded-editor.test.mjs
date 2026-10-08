import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../app/studio/canon/page.tsx', import.meta.url), 'utf8');
const editor = readFileSync(new URL('../app/studio/canon/guarded-editor.tsx', import.meta.url), 'utf8');

test('draft editor only renders behind guarded write feature flag', () => {
  assert.match(page, /SIDEWORLD_STUDIO_GUARDED_WRITES === 'enabled'/);
  assert.match(page, /enabled && selected \? <GuardedEditor/);
});
test('draft editor sends canonical universe identity and selected slug to guarded API', () => {
  assert.match(editor, /universeId, slug, name, status: 'draft'/);
  assert.match(editor, /\/api\/studio\/write\?universe=/);
  assert.match(editor, /encodeURIComponent\(universeSlug\)/);
});
