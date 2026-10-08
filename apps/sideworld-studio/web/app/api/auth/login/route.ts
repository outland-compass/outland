import { NextRequest, NextResponse } from 'next/server';
import { checkCredentials, setSession } from '@/lib/studio/auth';

export const runtime = 'nodejs';

export async function POST(request: NextRequest) {
  if (Number(request.headers.get('content-length') || 0) > 4096) return NextResponse.json({ error: 'Invalid request' }, { status: 413 });
  if (request.headers.get('origin') !== request.nextUrl.origin) return NextResponse.json({ error: 'Invalid origin' }, { status: 403 });
  try {
    const body = await request.json();
    if (typeof body.email !== 'string' || typeof body.password !== 'string' || body.email.length > 254 || body.password.length > 1024) {
      return NextResponse.json({ error: 'Invalid credentials' }, { status: 400 });
    }
    const session = await checkCredentials(body.email.trim(), body.password);
    if (!session) return NextResponse.json({ error: 'Invalid credentials or insufficient permissions' }, { status: 401 });
    const response = NextResponse.json({ ok: true });
    setSession(response, session);
    return response;
  } catch {
    return NextResponse.json({ error: 'Sign-in unavailable' }, { status: 503 });
  }
}
