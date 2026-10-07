import { NextResponse } from 'next/server';

import {
  createStudioSession,
  STUDIO_SESSION_COOKIE,
  STUDIO_SESSION_TTL_SECONDS,
  validateStudioAccessKey
} from '@/lib/session';

export const runtime = 'nodejs';

export async function POST(request: Request) {
  const contentLength = Number(request.headers.get('content-length') ?? '0');
  if (contentLength > 1024) {
    return NextResponse.json({ error: 'Access denied.' }, { status: 413 });
  }

  let key = '';

  try {
    const body = await request.json() as { key?: unknown };
    key = typeof body.key === 'string' && body.key.length <= 256 ? body.key : '';
  } catch {
    return NextResponse.json({ error: 'Access denied.' }, { status: 400 });
  }

  try {
    if (!validateStudioAccessKey(key)) {
      return NextResponse.json({ error: 'Access denied.' }, { status: 401 });
    }
  } catch {
    return NextResponse.json({ error: 'Studio access is unavailable.' }, { status: 503 });
  }

  const response = NextResponse.json({ ok: true });
  response.cookies.set({
    name: STUDIO_SESSION_COOKIE,
    value: createStudioSession(),
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: STUDIO_SESSION_TTL_SECONDS,
    path: '/'
  });
  response.headers.set('Cache-Control', 'private, no-store');
  return response;
}
