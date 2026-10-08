import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
const api = readFileSync(new URL('../app/api/studio/character-gallery/route.ts', import.meta.url), 'utf8');
const ui = readFileSync(new URL('../app/studio/characters/character-gallery.tsx', import.meta.url), 'utf8');
const page = readFileSync(new URL('../app/studio/characters/page.tsx', import.meta.url), 'utf8');
test('gallery uses authenticated service-only RPC scoped to franchise and universe', () => {
  assert.match(api, /authorize\(request, authResponse\)/);
  assert.match(api, /sideworld_character_media_gallery/);
  assert.match(api, /p_universe_slug: 'the-uncharted'/);
  assert.match(api, /p_franchise_slug: 'beyond-the-atlas'/);
});
test('gallery exposes metadata without private storage URLs', () => {
  assert.doesNotMatch(api, /createSignedUrl|object\/authenticated/);
  assert.match(api, /Cache-Control.*private, no-store/);
  assert.match(ui, /No stored portrait yet/);
  assert.match(ui, /approval_status/);
  assert.match(page, /<CharacterGallery \/>/);
});
