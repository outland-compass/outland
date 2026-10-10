import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const source = readFileSync(new URL('../lib/studio/puzzle-generation.ts', import.meta.url), 'utf8');

test('puzzle generation is bounded and refuses incomplete manifests', () => {
  assert.match(source, /!manifest\.readyForGeneration/);
  assert.match(source, /maximumCandidates > 10/);
  assert.match(source, /request\.context\.cityId !== manifest\.cityId/);
  assert.match(source, /request\.context\.universeId !== manifest\.universeId/);
});
test('untrusted model output is reviewed as draft and constrained to approved IDs', () => {
  assert.match(source, /status: 'draft_requires_review'/);
  assert.match(source, /validatePuzzleCandidateV1/);
  assert.match(source, /candidate\.mechanicId/);
  assert.match(source, /Unknown candidate fields/);
  assert.match(source, /Model exceeded candidate limit/);
});
test('no provider calls, writes or publication in generation contract', () => {
  assert.doesNotMatch(source, /fetch\(|callStudioRpc|\.insert\(|\.update\(|publishQuest\(/);
});
