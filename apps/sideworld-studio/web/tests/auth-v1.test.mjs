import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';

const read = (path) => readFileSync(new URL(path, import.meta.url), 'utf8');

test('studio uses individual Supabase Auth sessions, not shared key', () => {
  const auth = read('../lib/studio/auth.ts');
  const proxy = read('../proxy.ts');
  const write = read('../app/api/studio/write/route.ts');
  assert.match(auth, /grant_type=password/);
  assert.match(auth, /grant_type=refresh_token/);
  assert.match(auth, /rpc\/can_admin/);
  assert.match(auth, /auth\/v1\/user/);
  assert.match(proxy, /await authorize\(request, response\)/);
  assert.match(write, /await authorize\(request, NextResponse.next\(\)\)/);
  assert.doesNotMatch(write + proxy, /verifyStudioSession|STUDIO_SESSION_COOKIE/);
});

test('legacy access endpoint is disabled and write checks origin', () => {
  assert.match(read('../app/api/access/route.ts'), /status: 410/);
  assert.match(read('../app/api/studio/write/route.ts'), /Invalid origin/);
});
