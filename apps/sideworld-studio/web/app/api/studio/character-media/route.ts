import { createHash } from 'node:crypto';
import { NextRequest, NextResponse } from 'next/server';
import { authorize } from '@/lib/studio/auth';
import { deleteUnregisteredCharacterOriginal, lookupCharacterForMedia, registerCharacterOriginal, uploadCharacterOriginal } from '@/lib/studio/character-media-storage';

export const runtime = 'nodejs';
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
const SHA = /^[a-f0-9]{64}$/;
const MAX_BYTES = 10 * 1024 * 1024;

export async function POST(request: NextRequest) {
  if (request.headers.get('origin') !== request.nextUrl.origin) return NextResponse.json({ error: 'Invalid origin' }, { status: 403 });
  const response = NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  if (!await authorize(request, response)) return response;
  if (process.env.SIDEWORLD_CHARACTER_MEDIA_WRITES !== 'enabled') return NextResponse.json({ error: 'Character media uploads disabled' }, { status: 503 });
  const universe = request.nextUrl.searchParams.get('universe') ?? '';
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(universe)) return NextResponse.json({ error: 'Invalid universe' }, { status: 400 });
  const length = Number(request.headers.get('content-length') ?? '0');
  if (length > MAX_BYTES + 20_000) return NextResponse.json({ error: 'File too large' }, { status: 413 });

  let form: FormData;
  try { form = await request.formData(); } catch { return NextResponse.json({ error: 'Invalid multipart upload' }, { status: 400 }); }
  const file = form.get('file');
  const characterId = form.get('characterId');
  const visualVersion = Number(form.get('visualVersion'));
  const expectedHash = form.get('sha256');
  const sourceDocument = form.get('sourceDocument');
  if (!(file instanceof File) || typeof characterId !== 'string' || !UUID.test(characterId) ||
      !Number.isInteger(visualVersion) || visualVersion < 1 || visualVersion > 1000 ||
      typeof expectedHash !== 'string' || !SHA.test(expectedHash) ||
      typeof sourceDocument !== 'string' || sourceDocument.length > 200 ||
      !['image/png', 'image/jpeg', 'image/webp'].includes(file.type) ||
      file.size < 1 || file.size > MAX_BYTES) return NextResponse.json({ error: 'Invalid media input' }, { status: 400 });

  const bytes = new Uint8Array(await file.arrayBuffer());
  const hash = createHash('sha256').update(bytes).digest('hex');
  if (hash !== expectedHash) return NextResponse.json({ error: 'Original image SHA-256 mismatch' }, { status: 422 });

  try {
    if (!await lookupCharacterForMedia(characterId, universe)) return NextResponse.json({ error: 'Character not found in selected universe' }, { status: 404 });
    const stored = await uploadCharacterOriginal({
      characterId, visualVersion, sourceSha256: hash,
      mimeType: file.type as 'image/png' | 'image/jpeg' | 'image/webp', bytes
    });
    try {
      await registerCharacterOriginal({ characterId, visualVersion, path: stored.path, sha256: hash, sourceDocument });
    } catch (error) {
      try { await deleteUnregisteredCharacterOriginal(stored.path); } catch (cleanupError) {
        console.error('Character media cleanup requires manual reconciliation', cleanupError);
      }
      throw error;
    }
    return NextResponse.json({ status: 'draft', characterId, visualVersion, sha256: hash }, { status: 201 });
  } catch (error) {
    console.error('Character media upload failed', error);
    return NextResponse.json({ error: 'Media upload failed; check server logs' }, { status: 500 });
  }
}
