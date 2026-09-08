import 'server-only';

import { createHash, createHmac, timingSafeEqual } from 'node:crypto';

export const SESSION_COOKIE = 'outland_world_session';
export const SESSION_TTL_SECONDS = 60 * 60 * 12;

type SessionPayload = {
  exp: number;
  scope: 'world-v0';
};

function encode(value: string) {
  return Buffer.from(value).toString('base64url');
}

function decode(value: string) {
  return Buffer.from(value, 'base64url').toString('utf8');
}

function secret() {
  const value = process.env.WORLD_SESSION_SECRET;
  if (!value || value.length < 32) {
    throw new Error('WORLD_SESSION_SECRET must contain at least 32 characters.');
  }
  return value;
}

function equalStrings(left: string, right: string) {
  const leftBuffer = Buffer.from(left);
  const rightBuffer = Buffer.from(right);
  return leftBuffer.length === rightBuffer.length && timingSafeEqual(leftBuffer, rightBuffer);
}

function signature(payload: string) {
  return createHmac('sha256', secret()).update(payload).digest('base64url');
}

export function normalizeAccessKey(value: string) {
  return value.trim().normalize('NFKC');
}

export function hashAccessKey(value: string) {
  return createHash('sha256').update(normalizeAccessKey(value)).digest('hex');
}

export function validateAccessKey(value: string) {
  const expected = process.env.WORLD_ACCESS_KEY_HASH?.trim().toLowerCase();
  if (!expected || !/^[a-f0-9]{64}$/.test(expected)) {
    throw new Error('WORLD_ACCESS_KEY_HASH must be a SHA-256 hex digest.');
  }
  return equalStrings(hashAccessKey(value), expected);
}

export function createSession(now = Date.now()) {
  const payload = encode(JSON.stringify({
    exp: Math.floor(now / 1000) + SESSION_TTL_SECONDS,
    scope: 'world-v0'
  } satisfies SessionPayload));
  return `${payload}.${signature(payload)}`;
}

export function verifySession(token: string | undefined, now = Date.now()) {
  if (!token) return false;

  const [payload, providedSignature, extra] = token.split('.');
  if (!payload || !providedSignature || extra || !equalStrings(signature(payload), providedSignature)) {
    return false;
  }

  try {
    const parsed = JSON.parse(decode(payload)) as SessionPayload;
    return parsed.scope === 'world-v0' && parsed.exp > Math.floor(now / 1000);
  } catch {
    return false;
  }
}
