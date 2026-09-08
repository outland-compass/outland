import assert from 'node:assert/strict';
import test from 'node:test';
import { createHash, createHmac, timingSafeEqual } from 'node:crypto';

const normalize = (value) => value.trim().normalize('NFKC');
const hash = (value) => createHash('sha256').update(normalize(value)).digest('hex');
const sign = (payload, secret) => createHmac('sha256', secret).update(payload).digest('base64url');
const equal = (left, right) => {
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
};

test('access key digest is stable after surrounding whitespace normalization', () => {
  assert.equal(hash(' sample-key '), hash('sample-key'));
});

test('session signature rejects a changed payload', () => {
  const secret = 'a'.repeat(32);
  const payload = Buffer.from(JSON.stringify({ scope: 'world-v0', exp: 200 })).toString('base64url');
  const signature = sign(payload, secret);
  const changed = Buffer.from(JSON.stringify({ scope: 'world-v0', exp: 999 })).toString('base64url');
  assert.equal(equal(sign(changed, secret), signature), false);
});
