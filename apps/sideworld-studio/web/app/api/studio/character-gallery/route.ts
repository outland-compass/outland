import { NextRequest, NextResponse } from 'next/server';
import { authorize } from '@/lib/studio/auth';

export const runtime = 'nodejs';

type Asset = {
  id: string; character_id: string; visual_version: number; asset_role: string;
  approval_status: string; source_sha256: string; storage_path: string;
  source_document: string | null; rights_note: string; approved_at: string | null;
  created_at: string;
};

/** Admin-only metadata gallery; never returns service keys, private object URLs or signed URLs. */
export async function GET(request: NextRequest) {
  const authResponse = NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  if (!await authorize(request, authResponse)) return authResponse;
  const universe = request.nextUrl.searchParams.get('universe');
  if (universe !== 'the-uncharted') return NextResponse.json({ error: 'Unsupported universe' }, { status: 400 });
  const base = process.env.SUPABASE_URL?.trim().replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!base || !key) return NextResponse.json({ error: 'Unavailable' }, { status: 503 });
  try {
    const response = await fetch(`${base}/rest/v1/rpc/sideworld_character_media_gallery`, {
      method: 'POST',
      headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_universe_slug: 'the-uncharted', p_franchise_slug: 'beyond-the-atlas' }),
      cache: 'no-store', signal: AbortSignal.timeout(10_000)
    });
    if (!response.ok) throw new Error(`Gallery RPC failed: HTTP ${response.status}`);
    const data = await response.json();
    return NextResponse.json(data, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Character gallery RPC failed', error);
    return NextResponse.json({ error: 'Gallery unavailable' }, { status: 503 });
  }
}
