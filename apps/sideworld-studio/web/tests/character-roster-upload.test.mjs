import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const roster = readFileSync(new URL('../app/api/studio/character-roster/route.ts', import.meta.url), 'utf8');
const review = readFileSync(new URL('../app/studio/characters/character-media-review.tsx', import.meta.url), 'utf8');

test('roster requires admin session and scopes to canonical franchise', () => {
  assert.match(roster, /authorize\(request, response\)/);
  assert.match(roster, /p_franchise_slug: 'beyond-the-atlas'/);
  assert.match(roster, /sideworld_character_media_gallery/);
  assert.match(roster, /Cache-Control.*private, no-store/);
});
test('portrait upload requires integrity-verified original and real character ID', () => {
  assert.match(review, /roster\.find\(entry => entry\.slug === 'amon-dimano'\)/);
  assert.match(review, /previews\[canonical\.canonicalSourceFile\]\?\.verified/);
  assert.match(review, /body\.set\('characterId', character\.id\)/);
  assert.match(review, /body\.set\('sha256', canonical\.canonicalSha256\)/);
});
