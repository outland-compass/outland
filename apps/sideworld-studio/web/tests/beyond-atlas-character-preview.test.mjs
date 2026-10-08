import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const preview = readFileSync(new URL('../lib/studio/beyond-atlas-character-preview.ts', import.meta.url), 'utf8');
const page = readFileSync(new URL('../app/studio/characters/page.tsx', import.meta.url), 'utf8');
const nav = readFileSync(new URL('../app/studio/studio-sidebar.tsx', import.meta.url), 'utf8');

test('current Beyond the Atlas V1.12 names replace superseded drafts', () => {
  for (const name of ['Damien Wayne', 'Audrey Quin', 'Iris Wayne', 'Amon Dimano', 'Maria', 'Maya']) assert.ok(preview.includes(name));
  assert.doesNotMatch(preview, /Alexander Cross|Sophia Blake|Iris Cross/);
  assert.match(preview, /sourceVersion: '1\.12'/);
});

test('approved reference constraints remain visible and no write path exists', () => {
  assert.match(preview, /user_supplied_reference/);
  assert.match(preview, /existing_approved_portrait/);
  assert.match(preview, /Omar family name is provisional/);
  assert.match(page, /READ ONLY/);
  assert.match(nav, /\/studio\/characters/);
  assert.doesNotMatch(page, /fetch\(|callStudioRpc|\.insert\(|\.update\(/);
});

test('Amon user-approved visual version pins exact original image hash and archives alternative', () => {
  assert.match(preview, /canonicalSourceFile: 'image13\\.png'/);
  assert.match(preview, /canonicalSha256: '6c5836fee48b9a3ba9638f8723eda4d2f979d162cd5b929707584c83ef25ed28'/);
  assert.match(preview, /archivedAlternativeFile: 'image12\\.png'/);
  assert.match(preview, /storageStatus: 'not_uploaded'/);
  assert.match(page, /Approved editorial selection: Amon Dimano/);
});
