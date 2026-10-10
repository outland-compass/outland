import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';

const sql = readFileSync(new URL('../../../../supabase/migrations/20261008130549_sideworld_studio_guarded_canon_writes.sql', import.meta.url), 'utf8');

test('canon writes check universe, franchise and existing entity atomically', () => {
  assert.match(sql, /from universe\.universes where slug=p_universe_slug for update/);
  assert.match(sql, /from canon\.franchises where id=v_franchise for update/);
  for (const entity of ['series', 'characters', 'factions', 'lore_facts', 'canon_rules']) {
    assert.match(sql, new RegExp('from canon\\.' + entity + ' where id=v_id for update'));
  }
});
test('optional theme, series and character references cannot cross franchises or universes', () => {
  assert.match(sql, /Theme universe mismatch/);
  assert.match(sql, /Lore series franchise mismatch/);
  assert.match(sql, /Rule series franchise mismatch/);
  assert.match(sql, /Rule character franchise mismatch/);
});
test('guarded canon RPC is service-role only', () => {
  assert.match(sql, /revoke all .*from public, anon, authenticated/);
  assert.match(sql, /grant execute .*to service_role/);
});
