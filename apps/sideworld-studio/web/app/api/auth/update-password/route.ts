import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  if (request.headers.get('origin') !== request.nextUrl.origin) return NextResponse.json({ error: 'Invalid origin' }, { status: 403 });
  try {
    const body = await request.json();
    if (typeof body.token !== 'string' || typeof body.password !== 'string' || body.password.length < 12 || body.password.length > 1024) {
      return NextResponse.json({ error: 'Invalid password reset request' }, { status: 400 });
    }
    const url = process.env.SUPABASE_URL?.trim();
    const key = process.env.SUPABASE_PUBLISHABLE_KEY?.trim();
    if (!url || !key) throw new Error('Missing Auth configuration');
    const response = await fetch(`${url.replace(/\/$/, '')}/auth/v1/user`, {
      method: 'PUT', cache: 'no-store',
      headers: { apikey: key, Authorization: `Bearer ${body.token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: body.password })
    });
    if (!response.ok) return NextResponse.json({ error: 'Reset link expired or invalid' }, { status: 400 });
    return NextResponse.json({ ok: true });
  } catch {
    return NextResponse.json({ error: 'Password reset unavailable' }, { status: 503 });
  }
}
