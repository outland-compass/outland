import 'server-only';

import { createHash, createHmac, timingSafeEqual } from 'node:crypto';

export const STUDIO_SESSION_COOKIE = 'sideworld_studio_session';
export const STUDIO_SESSION_TTL_SECONDS = 60 * 60 * 12;

type StudioSessionPayload = {
  exp: number;
  scope: 'sideworld-studio-v0';
};

function encode(value: string) {
  return Buffer.from(value).toString('base64url');
}

function decode(value: string) {
  return Buffer.from(value, 'base64url').toString('utf8');
}

function secret() {
  const value = process.env.STUDIO_SESSION_SECRET;
  if (!value || value.length < 32) {
    throw new Error('STUDIO_SESSION_SECRET must contain at least 32 characters.');
  }
  return value;
}

function equalStrings(left: string, right: string) {
  const a = Buffer.from(left);
  const b = Buffer.from(right);
  return a.length === b.length && timingSafeEqual(a, b);
}

function signature(payload: string) {
  return createHmac('sha256', secret()).update(payload).digest('base64url');
}

export function normalizeStudioAccessKey(value: string) {
  return value.trim().normalize('NFKC');
}

export function hashStudioAccessKey(value: string) {
  return createHash('sha256').update(normalizeStudioAccessKey(value)).digest('hex');
}

export function validateStudioAccessKey(value: string) {
  const expected = process.env.STUDIO_ACCESS_KEY_HASH?.trim().toLowerCase();
  if (!expected || !/^[a-f0-9]{64}$/.test(expected)) {
    throw new Error('STUDIO_ACCESS_KEY_HASH must be a SHA-256 hex digest.');
  }
  return equalStrings(hashStudioAccessKey(value), expected);
}

export function createStudioSession(now = Date.now()) {
  const payload = encode(JSON.stringify({
    exp: Math.floor(now / 1000) + STUDIO_SESSION_TTL_SECONDS,
    scope: 'sideworld-studio-v0'
  } satisfies StudioSessionPayload));

  return `${payload}.${signature(payload)}`;
}

export function verifyStudioSession(token: string | undefined, now = Date.now()) {
  if (!token) return false;

  const [payload, providedSignature, extra] = token.split('.');
  if (!payload || !providedSignature || extra || !equalStrings(signature(payload), providedSignature)) {
    return false;
  }

  try {
    const parsed = JSON.parse(decode(payload)) as StudioSessionPayload;
    return parsed.scope === 'sideworld-studio-v0' && parsed.exp > Math.floor(now / 1000);
  } catch {
    return false;
  }
}
