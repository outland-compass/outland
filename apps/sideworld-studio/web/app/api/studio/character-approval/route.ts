import { NextRequest, NextResponse } from 'next/server';
import { authorize } from '@/lib/studio/auth';
import { lookupCharacterForMedia } from '@/lib/studio/character-media-storage';

export const runtime = 'nodejs';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function POST(request: NextRequest) {
  const denied = NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  if (!await authorize(request, denied)) return denied;
  if (request.headers.get('origin') !== request.nextUrl.origin)
    return NextResponse.json({ error: 'Origin mismatch' }, { status: 403 });
  if (process.env.SIDEWORLD_CHARACTER_APPROVAL_WRITES !== 'enabled')
    return NextResponse.json({ error: 'Character approvals disabled' }, { status: 403 });
  if (request.headers.get('content-type')?.split(';')[0] !== 'application/json')
    return NextResponse.json({ error: 'JSON required' }, { status: 415 });
  if (Number(request.headers.get('content-length') || 0) > 4096)
    return NextResponse.json({ error: 'Payload too large' }, { status: 413 });
  const body = await request.json().catch(() => null);
  if (!body || typeof body !== 'object') return NextResponse.json({ error: 'Invalid payload' }, { status: 400 });
  const { assetId, characterId, expectedSha256, rightsNote, action } = body as Record<string, unknown>;
  if (![assetId, characterId].every(value => typeof value === 'string' && UUID.test(value)) ||
      typeof expectedSha256 !== 'string' || !/^[a-f0-9]{64}$/.test(expectedSha256) ||
      typeof rightsNote !== 'string' || rightsNote.trim().length < 20 || rightsNote.length > 1000 ||
      action !== 'approve')
    return NextResponse.json({ error: 'Invalid approval request' }, { status: 400 });
  const base = process.env.SUPABASE_URL?.trim().replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  const publishable = process.env.SUPABASE_PUBLISHABLE_KEY?.trim();
  const access = request.cookies.get('sw_studio_access')?.value;
  if (!base || !key || !publishable || !access) return NextResponse.json({ error: 'Approval unavailable' }, { status: 503 });
  try {
    if (!await lookupCharacterForMedia(characterId as string, 'the-uncharted'))
      return NextResponse.json({ error: 'Character out of scope' }, { status: 403 });
    const identity = await fetch(`${base}/auth/v1/user`, {
      headers: { apikey: publishable, Authorization: `Bearer ${access}` },
      cache: 'no-store', signal: AbortSignal.timeout(10_000)
    });
    if (!identity.ok) return NextResponse.json({ error: 'Session expired' }, { status: 401 });
    const user = await identity.json() as { id?: string };
    if (!user.id || !UUID.test(user.id)) return NextResponse.json({ error: 'Invalid session' }, { status: 401 });
    const url = new URL(`${base}/rest/v1/character_visual_assets`);
    url.searchParams.set('id', `eq.${assetId}`);
    url.searchParams.set('character_id', `eq.${characterId}`);
    url.searchParams.set('source_sha256', `eq.${expectedSha256}`);
    url.searchParams.set('approval_status', 'eq.draft');
    const result = await fetch(url, {
      method: 'PATCH',
      headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Profile': 'canon',
        'Content-Type': 'application/json', Prefer: 'return=representation' },
      body: JSON.stringify({ approval_status: 'approved', rights_note: rightsNote.trim(),
        approved_by: user.id, approved_at: new Date().toISOString() }),
      cache: 'no-store', signal: AbortSignal.timeout(10_000)
    });
    if (!result.ok) {
      console.error('Character approval update rejected', result.status);
      return NextResponse.json({ error: 'Approval failed or version conflict' }, { status: 409 });
    }
    const rows = await result.json() as Array<{ id: string }>;
    if (rows.length !== 1) return NextResponse.json({ error: 'Draft no longer available' }, { status: 409 });
    return NextResponse.json({ approved: true, assetId }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Character approval failed', error);
    return NextResponse.json({ error: 'Approval unavailable' }, { status: 503 });
  }
}
