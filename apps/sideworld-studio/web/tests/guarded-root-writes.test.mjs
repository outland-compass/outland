import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const migration = readFileSync(new URL('../../../../supabase/migrations/20261008130547_sideworld_studio_guarded_root_writes.sql', import.meta.url), 'utf8');
const route = readFileSync(new URL('../app/api/studio/write/route.ts', import.meta.url), 'utf8');

test('root writes validate canonical universe and existing entity inside same transaction', () => {
  assert.match(migration, /from universe\.universes[\s\S]*for update/);
  assert.match(migration, /from universe\.worlds where id=v_id for update/);
  assert.match(migration, /from universe\.themes where id=v_id for update/);
  assert.match(migration, /from canon\.franchises where id=v_id for update/);
  assert.match(migration, /v_requested is distinct from v_universe/);
  assert.match(migration, /v_existing is distinct from v_universe/);
});
test('guarded RPC only grants service role and does not alter existing write functions', () => {
  assert.match(migration, /revoke all .*from public, anon, authenticated/);
  assert.match(migration, /grant execute .*to service_role/);
  assert.doesNotMatch(migration, /drop table|alter table|truncate/i);
});
test('writes remain fail-closed pending indirect entity and shared geo rules', () => {
  assert.match(route, /Studio writes temporarily disabled pending universe ownership validation/);
  assert.match(route, /status: 503/);
});
