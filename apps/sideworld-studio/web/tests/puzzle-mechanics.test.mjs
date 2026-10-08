import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const registry = readFileSync(new URL('../lib/studio/puzzle-mechanics.ts', import.meta.url), 'utf8');

test('registry provides six stable, versioned mechanics', () => {
  for (const id of ['observation', 'deduction', 'sequence', 'cipher', 'navigation', 'dialogue']) {
    assert.match(registry, new RegExp("id: '" + id + "'"));
  }
  assert.match(registry, /version: 1/g);
  assert.match(registry, /accessibilityFallback/);
  assert.match(registry, /safetyConstraints/);
  assert.match(registry, /automatedChecks/);
});

test('candidate validation rejects unapproved locations, facts and characters', () => {
  assert.match(registry, /allowed\.locationIds\.includes\(candidate\.locationId\)/);
  assert.match(registry, /allowed\.factIds\.includes\(id\)/);
  assert.match(registry, /allowed\.characterIds\.includes\(id\)/);
  assert.match(registry, /At least two progressive hints are required/);
});

test('puzzle registry does not call AI or mutate databases', () => {
  assert.doesNotMatch(registry, /fetch\(|callStudioRpc|\.insert\(|\.update\(/);
});
