import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../app/studio/characters/page.tsx', import.meta.url), 'utf8');
const review = readFileSync(new URL('../app/studio/characters/character-media-review.tsx', import.meta.url), 'utf8');

test('Character Studio embeds read-only media review', () => {
  assert.match(page, /<CharacterMediaReview/);
  assert.match(review, /extraction-report\.json/);
  assert.match(review, /Export draft mapping JSON/);
  assert.match(review, /approved: false/);
});
test('media mapping remains browser-local without backend writes', () => {
  assert.doesNotMatch(review, /fetch\(|supabase|callStudioRpc|\.insert\(|\.update\(/);
  assert.match(review, /URL\.createObjectURL/);
});

test('original portraits are SHA-256 verified before local preview', () => {
  assert.match(review, /crypto\.subtle\.digest\('SHA-256'/);
  assert.match(review, /verified \? URL\.createObjectURL\(file\)/);
  assert.match(review, /approved canonical portrait V1/);
});
