import { NextResponse } from 'next/server';

// Legacy shared access-key authentication is permanently disabled.
export async function POST() {
  return NextResponse.json({ error: 'Use email and password sign-in.' }, { status: 410 });
}
