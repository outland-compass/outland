import { NextResponse } from 'next/server';

import {
  createSession,
  SESSION_COOKIE,
  SESSION_TTL_SECONDS,
  validateAccessKey
} from '@/lib/session';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  const contentLength = Number(request.headers.get('content-length') ?? '0');
  if (contentLength > 1024) {
    return NextResponse.json({ error: 'That key did not open anything.' }, { status: 413 });
  }

  let key = '';

  try {
    const body = await request.json() as { key?: unknown };
    key = typeof body.key === 'string' && body.key.length <= 256 ? body.key : '';
  } catch {
    return NextResponse.json({ error: 'That key did not open anything.' }, { status: 400 });
  }

  try {
    if (!validateAccessKey(key)) {
      return NextResponse.json({ error: 'That key did not open anything.' }, { status: 401 });
    }
  } catch {
    return NextResponse.json({ error: 'Access is temporarily unavailable.' }, { status: 503 });
  }

  const response = NextResponse.json({ ok: true });
  response.cookies.set({
    name: SESSION_COOKIE,
    value: createSession(),
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: SESSION_TTL_SECONDS,
    path: '/'
  });
  response.headers.set('Cache-Control', 'private, no-store');
  return response;
}
