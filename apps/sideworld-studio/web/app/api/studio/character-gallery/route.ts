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
  const headers = { apikey: key, Authorization: `Bearer ${key}` };
  const get = async (schema: string, table: string, query: Record<string, string>) => {
    const url = new URL(`${base}/rest/v1/${table}`);
    Object.entries(query).forEach(([name, value]) => url.searchParams.set(name, value));
    const response = await fetch(url, { headers: { ...headers, 'Accept-Profile': schema }, cache: 'no-store', signal: AbortSignal.timeout(10_000) });
    if (!response.ok) throw new Error(`Canon gallery lookup failed: HTTP ${response.status}`);
    return response.json();
  };
  try {
    const universes = await get('universe', 'universes', { select: 'id', slug: 'eq.the-uncharted' }) as Array<{ id: string }>;
    if (universes.length !== 1) return NextResponse.json({ characters: [], assets: [] });
    const franchises = await get('canon', 'franchises', { select: 'id', universe_id: `eq.${universes[0].id}`, slug: 'eq.beyond-the-atlas' }) as Array<{ id: string }>;
    if (franchises.length !== 1) return NextResponse.json({ characters: [], assets: [] });
    const characters = await get('canon', 'characters', { select: 'id,slug,name,canon_status', franchise_id: `eq.${franchises[0].id}`, order: 'name.asc' }) as Array<{ id: string; slug: string; name: string; canon_status: string }>;
    const ids = characters.map(c => c.id);
    const assets = ids.length
      ? await get('canon', 'character_visual_assets', {
          select: 'id,character_id,visual_version,asset_role,approval_status,source_sha256,storage_path,source_document,rights_note,approved_at,created_at',
          character_id: `in.(${ids.join(',')})`, order: 'created_at.desc', limit: '200'
        }) as Asset[]
      : [];
    return NextResponse.json({ characters, assets }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Character gallery lookup failed', error);
    return NextResponse.json({ error: 'Gallery unavailable' }, { status: 503 });
  }
}
