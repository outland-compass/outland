import { NextRequest, NextResponse } from 'next/server';
import { sendPasswordReset } from '@/lib/studio/auth';

export async function POST(request: NextRequest) {
  if (request.headers.get('origin') !== request.nextUrl.origin) return NextResponse.json({ error: 'Invalid origin' }, { status: 403 });
  try {
    const body = await request.json();
    if (typeof body.email !== 'string' || body.email.length > 254) return NextResponse.json({ error: 'Invalid email' }, { status: 400 });
    // Generic response prevents account enumeration. Redirect must be allowlisted in Supabase Auth.
    await sendPasswordReset(body.email.trim(), `${request.nextUrl.origin}/reset-password`);
  } catch {
    // Do not expose account existence or provider details.
  }
  return NextResponse.json({ ok: true, message: 'If the account exists, check your email.' });
}
