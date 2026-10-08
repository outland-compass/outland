import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const sql = readFileSync(new URL('../../../../supabase/migrations/202610080008_fix_guarded_faction_dispatch.sql', import.meta.url), 'utf8');
const route = readFileSync(new URL('../app/api/studio/write/route.ts', import.meta.url), 'utf8');

test('faction is explicitly dispatched, not passed to canon rule fallback', () => {
  assert.match(sql, /elsif p_entity='faction' then[\s\S]*?return public\.sideworld_studio_save_faction\(/);
  assert.match(sql, /elsif p_entity='lore' then/);
  assert.match(sql, /return public\.sideworld_studio_save_canon_rule\(/);
});
test('faction visibility API values match database check constraint', () => {
  assert.match(route, /p_visibility: oneOf\(input\.visibility, 'visibility', \['hidden','partial','public'\], 'hidden'\)/);
});
