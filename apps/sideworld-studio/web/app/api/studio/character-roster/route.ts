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
    const universes = new URL(`${base}/rest/v1/universes`);
    universes.searchParams.set('select', 'id');
    universes.searchParams.set('slug', `eq.${universeSlug}`);
    const u = await fetch(universes, { headers: { ...headers, 'Accept-Profile': 'universe' }, cache: 'no-store' });
    if (!u.ok) throw new Error('Universe lookup failed');
    const universeRows = await u.json() as Array<{ id: string }>;
    if (universeRows.length !== 1) return NextResponse.json({ characters: [] });
    const franchises = new URL(`${base}/rest/v1/franchises`);
    franchises.searchParams.set('select', 'id');
    franchises.searchParams.set('universe_id', `eq.${universeRows[0].id}`);
    franchises.searchParams.set('slug', 'eq.beyond-the-atlas');
    const f = await fetch(franchises, { headers: { ...headers, 'Accept-Profile': 'canon' }, cache: 'no-store' });
    if (!f.ok) throw new Error('Franchise lookup failed');
    const franchiseRows = await f.json() as Array<{ id: string }>;
    if (franchiseRows.length !== 1) return NextResponse.json({ characters: [] });
    const characters = new URL(`${base}/rest/v1/characters`);
    characters.searchParams.set('select', 'id,slug,name,canon_status');
    characters.searchParams.set('franchise_id', `eq.${franchiseRows[0].id}`);
    characters.searchParams.set('order', 'name.asc');
    const c = await fetch(characters, { headers: { ...headers, 'Accept-Profile': 'canon' }, cache: 'no-store' });
    if (!c.ok) throw new Error('Character lookup failed');
    const rows = await c.json() as Array<{ id: string; slug: string; name: string; canon_status: string }>;
    return NextResponse.json({ characters: rows }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Character roster lookup failed', error);
    return NextResponse.json({ error: 'Character roster unavailable' }, { status: 503 });
  }
}
