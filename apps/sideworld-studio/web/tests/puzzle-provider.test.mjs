import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const adapter = readFileSync(new URL('../lib/studio/puzzle-provider.ts', import.meta.url), 'utf8');
const generator = readFileSync(new URL('../lib/studio/puzzle-generation.ts', import.meta.url), 'utf8');

test('provider boundary requires explicit provider and validates budget', () => {
  assert.match(adapter, /provider: PuzzleProviderV1/);
  assert.match(adapter, /checkBudget\(budget\)/);
  assert.match(adapter, /maxCandidates > 10/);
  assert.match(adapter, /maxOutputTokens > 4096/);
  assert.match(adapter, /maxTotalTokens > 20_000/);
  assert.match(adapter, /timeoutMs > 30_000/);
});

test('generated output always goes through draft review and usage checks', () => {
  assert.match(adapter, /reviewPuzzleGenerationOutputV1\(response\.output, manifest, request\)/);
  assert.match(adapter, /response\.inputTokens \+ response\.outputTokens > budget\.maxTotalTokens/);
  assert.match(generator, /status: 'draft_requires_review'/);
});

test('adapter has no direct network calls, credentials, writes or publishing', () => {
  assert.doesNotMatch(adapter, /fetch\(|process\.env|callStudioRpc|\.insert\(|\.update\(|publishQuest\(/);
});
