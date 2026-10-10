import { NextRequest, NextResponse } from 'next/server';
import { authorize } from '@/lib/studio/auth';

export const runtime = 'nodejs';

export async function GET(request: NextRequest) {
  const response = NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  if (!await authorize(request, response)) return response;
  const universeSlug = request.nextUrl.searchParams.get('universe');
  if (!universeSlug || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(universeSlug)) {
    return NextResponse.json({ error: 'Invalid universe' }, { status: 400 });
  }
  const base = process.env.SUPABASE_URL?.trim().replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!base || !key) return NextResponse.json({ error: 'Studio data unavailable' }, { status: 503 });
  const headers = { apikey: key, authorization: `Bearer ${key}` };
  try {
    if (universeSlug !== 'the-uncharted') return NextResponse.json({ characters: [] });
    const result = await fetch(`${base}/rest/v1/rpc/sideworld_character_media_gallery`, {
      method: 'POST',
      headers: { ...headers, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_universe_slug: universeSlug, p_franchise_slug: 'beyond-the-atlas' }),
      cache: 'no-store', signal: AbortSignal.timeout(10_000)
    });
    if (!result.ok) throw new Error('Character gallery RPC failed');
    const payload = await result.json() as { characters?: Array<{ id: string; slug: string; name: string; canon_status: string }> };
    const rows = Array.isArray(payload.characters) ? payload.characters : [];
    return NextResponse.json({ characters: rows }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Character roster lookup failed', error);
    return NextResponse.json({ error: 'Character roster unavailable' }, { status: 503 });
  }
}
