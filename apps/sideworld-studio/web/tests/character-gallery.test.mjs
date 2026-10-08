import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
const api = readFileSync(new URL('../app/api/studio/character-gallery/route.ts', import.meta.url), 'utf8');
const ui = readFileSync(new URL('../app/studio/characters/character-gallery.tsx', import.meta.url), 'utf8');
const page = readFileSync(new URL('../app/studio/characters/page.tsx', import.meta.url), 'utf8');
test('gallery is authenticated and scoped to Beyond the Atlas in THE UNCHARTED', () => {
  assert.match(api, /authorize\(request, authResponse\)/);
  assert.match(api, /eq\.the-uncharted/);
  assert.match(api, /eq\.beyond-the-atlas/);
  assert.match(api, /character_id: `in\.\(/);
});
test('gallery exposes metadata only and no private object URLs', () => {
  assert.doesNotMatch(api, /createSignedUrl|service_role.*json|object\/authenticated/);
  assert.match(api, /Cache-Control.*private, no-store/);
  assert.match(ui, /No stored portrait yet/);
  assert.match(ui, /approval_status/);
  assert.match(page, /<CharacterGallery \/>/);
});
