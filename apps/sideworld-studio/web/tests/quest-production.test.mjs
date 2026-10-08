import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const page = readFileSync(new URL('../app/studio/production/page.tsx', import.meta.url), 'utf8');
const sidebar = readFileSync(new URL('../app/studio/studio-sidebar.tsx', import.meta.url), 'utf8');

test('quest production is accessible from Studio navigation', () => {
  assert.match(sidebar, /Quest Production/);
  assert.match(sidebar, /\/studio\/production/);
});

test('production preflight is read-only and uses existing canon and city knowledge', () => {
  assert.match(page, /getStudioReadModel/);
  assert.match(page, /getCityKnowledge/);
  assert.match(page, /buildCanonContextV0/);
  assert.match(page, /checks\.every/);
  assert.doesNotMatch(page, /callStudioRpc|fetch\(|\.insert\(|\.update\(/);
});

test('preflight clearly distinguishes inputs from generated content', () => {
  assert.match(page, /does not call an AI model/);
  assert.match(page, /Field QA remains mandatory/);
});
