import { NextRequest, NextResponse } from 'next/server';
import { authorize } from '@/lib/studio/auth';
import { verifyStoredCharacterOriginal } from '@/lib/studio/character-media-storage';

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
  const rawBody = await request.text().catch(() => '');
  if (rawBody.length > 4096) return NextResponse.json({ error: 'Payload too large' }, { status: 413 });
  const body = (() => { try { return JSON.parse(rawBody); } catch { return null; } })();
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
    const identity = await fetch(`${base}/auth/v1/user`, {
      headers: { apikey: publishable, Authorization: `Bearer ${access}` },
      cache: 'no-store', signal: AbortSignal.timeout(10_000)
    });
    if (!identity.ok) return NextResponse.json({ error: 'Session expired' }, { status: 401 });
    const user = await identity.json() as { id?: string };
    if (!user.id || !UUID.test(user.id)) return NextResponse.json({ error: 'Invalid session' }, { status: 401 });
    // Recheck the private Storage bytes immediately before the irreversible editorial approval.
    const galleryResponse = await fetch(`${base}/rest/v1/rpc/sideworld_character_media_gallery`, {
      method: 'POST',
      headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ p_universe_slug: 'the-uncharted', p_franchise_slug: 'beyond-the-atlas' }),
      cache: 'no-store', signal: AbortSignal.timeout(10_000)
    });
    if (!galleryResponse.ok) return NextResponse.json({ error: 'Asset verification unavailable' }, { status: 503 });
    const gallery = await galleryResponse.json() as { assets?: Array<{ id: string; character_id: string; source_sha256: string; storage_path: string; approval_status: string; asset_role: string }> };
    const asset = gallery.assets?.find(a => a.id === assetId && a.character_id === characterId &&
      a.source_sha256 === expectedSha256 && a.approval_status === 'draft' && a.asset_role === 'canonical_portrait');
    if (!asset || !asset.storage_path.startsWith(`${characterId}/`) || asset.storage_path.includes('..'))
      return NextResponse.json({ error: 'Draft not found or invalid storage path' }, { status: 409 });
    await verifyStoredCharacterOriginal(asset.storage_path, expectedSha256);
    const result = await fetch(`${base}/rest/v1/rpc/sideworld_character_media_approve`, {
      method: 'POST',
      headers: { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        p_universe_slug: 'the-uncharted', p_franchise_slug: 'beyond-the-atlas',
        p_asset_id: assetId, p_character_id: characterId,
        p_expected_sha256: expectedSha256, p_rights_note: rightsNote.trim(),
        p_reviewer_id: user.id
      }),
      cache: 'no-store', signal: AbortSignal.timeout(10_000)
    });
    if (!result.ok) {
      console.error('Character approval RPC rejected', result.status);
      return NextResponse.json({ error: 'Approval failed or version conflict' }, { status: 409 });
    }
    if (await result.json() !== true)
      return NextResponse.json({ error: 'Draft no longer available' }, { status: 409 });
    return NextResponse.json({ approved: true, assetId }, { headers: { 'Cache-Control': 'private, no-store' } });
  } catch (error) {
    console.error('Character approval failed', error);
    return NextResponse.json({ error: 'Approval unavailable' }, { status: 503 });
  }
}
