import { NextRequest, NextResponse } from 'next/server';
import { clearSession } from '@/lib/studio/auth';

export async function POST(request: NextRequest) {
  if (request.headers.get('origin') !== request.nextUrl.origin) return NextResponse.json({ error: 'Invalid origin' }, { status: 403 });
  const response = NextResponse.json({ ok: true });
  clearSession(response);
  return response;
}
