import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';

test('Studio access uses a signed server-only session', async () => {
  const source = await readFile(new URL('../lib/session.ts', import.meta.url), 'utf8');
  assert.match(source, /STUDIO_SESSION_SECRET/);
  assert.match(source, /timingSafeEqual/);
  assert.doesNotMatch(source, /NEXT_PUBLIC_/);
});

test('Studio authoring API verifies the private session', async () => {
  const source = await readFile(new URL('../app/api/studio/write/route.ts', import.meta.url), 'utf8');
  assert.match(source, /verifyStudioSession/);
  assert.match(source, /sideworld_studio_save_universe/);
  assert.match(source, /sideworld_studio_save_canon_rule/);
  assert.match(source, /sideworld_studio_save_world/);
  assert.match(source, /sideworld_studio_save_city/);
  assert.match(source, /sideworld_studio_save_character/);
});

test('Studio RPC client keeps the service key server-only', async () => {
  const source = await readFile(new URL('../lib/studio/rpc.ts', import.meta.url), 'utf8');
  assert.match(source, /server-only/);
  assert.match(source, /SUPABASE_SERVICE_ROLE_KEY/);
  assert.doesNotMatch(source, /NEXT_PUBLIC_/);
});

test('Studio runtime reads from Supabase only', async () => {
  const source = await readFile(new URL('../lib/studio/read-model.ts', import.meta.url), 'utf8');
  assert.match(source, /return readFromSupabase\(\)/);
  assert.doesNotMatch(source, /STUDIO_DATA_SOURCE|from '.\/fixture'/);
});

test('fixture preserves the initial narrative structure', async () => {
  const source = await readFile(new URL('../lib/studio/fixture.ts', import.meta.url), 'utf8');
  assert.match(source, /The Lost Cartographers/);
  assert.match(source, /Placeholder only/);
  assert.doesNotMatch(source, /id: 'u-beyond-atlas'/);
  assert.match(source, /The Unbroken Line is an overarching mystery, not a series/);
});

test('Canon Context Builder is deterministic and approval-gated', async () => {
  const source = await readFile(new URL('../lib/studio/context-builder.ts', import.meta.url), 'utf8');
  assert.match(source, /contextVersion: 1/);
  assert.match(source, /item\.status === 'active'/);
  assert.match(source, /item\.canonStatus === 'approved'/);
  assert.match(source, /proposedLoreKeys\.has\(item\.factKey\)/);
  assert.match(source, /seriesSlugs\.has\(item\.slug\)/);
  assert.doesNotMatch(source, /Date\./);
  assert.doesNotMatch(source, /Math\.random/);
});

test('Studio exposes an explicit Canon Context selector and preview', async () => {
  const source = await readFile(new URL('../app/studio/context/page.tsx', import.meta.url), 'utf8');
  assert.match(source, /Approved context only by default/);
  assert.match(source, /buildCanonContextV0/);
  assert.match(source, /name="series"/);
  assert.match(source, /name="world"/);
  assert.match(source, /name="city"/);
  assert.match(source, /name="lore"/);
  assert.match(source, /Compile context/);
});

test('Studio City Knowledge reader stays server-only', async () => {
  const source = await readFile(new URL('../lib/studio/city-knowledge.ts', import.meta.url), 'utf8');
  assert.match(source, /server-only/);
  assert.match(source, /sideworld_studio_city_knowledge/);
});

test('Studio authoring API supports City Knowledge entities', async () => {
  const source = await readFile(new URL('../app/api/studio/write/route.ts', import.meta.url), 'utf8');
  assert.match(source, /sideworld_studio_save_location/);
  assert.match(source, /sideworld_studio_save_location_fact/);
  assert.match(source, /sideworld_studio_save_source/);
  assert.match(source, /sideworld_studio_save_fact_source/);
});

test('City Knowledge screen keeps facts and sources explicit', async () => {
  const source = await readFile(new URL('../app/studio/city/page.tsx', import.meta.url), 'utf8');
  assert.match(source, /Geographic truth before generated story/);
  assert.match(source, /Verification status and confidence remain explicit/);
  assert.match(source, /CityKnowledgeEditor/);
});
