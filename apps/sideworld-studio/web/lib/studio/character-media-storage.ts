import { createHash } from 'node:crypto';
import 'server-only';

const BUCKET = 'sideworld-character-media';

function credentials() {
  const base = process.env.SUPABASE_URL?.trim().replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
  if (!base || !key) throw new Error('Storage server credentials are missing');
  return { base, key };
}

function serviceHeaders(key: string) {
  return { apikey: key, Authorization: `Bearer ${key}` };
}

/** Server-only: no public URLs, signed URLs or browser service-role credentials. */
export async function uploadCharacterOriginal(input: {
  characterId: string;
  visualVersion: number;
  sourceSha256: string;
  mimeType: 'image/png' | 'image/jpeg' | 'image/webp';
  bytes: Uint8Array;
}) {
  const { base, key } = credentials();
  const extension = { 'image/png': 'png', 'image/jpeg': 'jpg', 'image/webp': 'webp' }[input.mimeType];
  const path = `${input.characterId}/v${input.visualVersion}/${input.sourceSha256}.${extension}`;
  const response = await fetch(`${base}/storage/v1/object/${BUCKET}/${path}`, {
    method: 'POST',
    headers: { ...serviceHeaders(key), 'Content-Type': input.mimeType, 'x-upsert': 'false', 'cache-control': 'no-store' },
    body: Buffer.from(input.bytes),
    cache: 'no-store',
    signal: AbortSignal.timeout(20_000)
  });
  if (!response.ok) throw new Error(`Private media upload failed: HTTP ${response.status}`);
  return { bucket: BUCKET, path };
}

export async function deleteUnregisteredCharacterOriginal(path: string) {
  const { base, key } = credentials();
  const response = await fetch(`${base}/storage/v1/object/${BUCKET}/${path}`, {
    method: 'DELETE', headers: serviceHeaders(key), cache: 'no-store',
    signal: AbortSignal.timeout(20_000)
  });
  if (!response.ok) throw new Error(`Media cleanup failed: HTTP ${response.status}`);
}

/** Verify canonical character → franchise → universe scope without trusting a client-supplied franchise. */
export async function lookupCharacterForMedia(characterId: string, universeSlug: string) {
  const { base, key } = credentials();
  async function single(schema: string, table: string, select: string, filter: string) {
    const url = new URL(`${base}/rest/v1/${table}`);
    url.searchParams.set('select', select);
    url.searchParams.set('id', `eq.${filter}`);
    const response = await fetch(url, {
      headers: { ...serviceHeaders(key), 'Accept-Profile': schema },
      cache: 'no-store', signal: AbortSignal.timeout(10_000)
    });
    if (!response.ok) throw new Error(`Canonical scope lookup failed: HTTP ${response.status}`);
    const rows: unknown = await response.json();
    return Array.isArray(rows) && rows.length === 1 ? rows[0] as Record<string, unknown> : null;
  }
  const character = await single('canon', 'characters', 'id,franchise_id', characterId);
  if (typeof character?.franchise_id !== 'string') return false;
  const franchise = await single('canon', 'franchises', 'id,universe_id', character.franchise_id);
  if (typeof franchise?.universe_id !== 'string') return false;
  const universe = await single('universe', 'universes', 'id,slug', franchise.universe_id);
  return universe?.slug === universeSlug;
}

export async function registerCharacterOriginal(input: {
  characterId: string; visualVersion: number; path: string; sha256: string; sourceDocument: string;
}) {
  const { base, key } = credentials();
  const response = await fetch(`${base}/rest/v1/character_visual_assets`, {
    method: 'POST',
    headers: { ...serviceHeaders(key), 'Content-Profile': 'canon', 'Content-Type': 'application/json', Prefer: 'return=minimal' },
    body: JSON.stringify({
      character_id: input.characterId, visual_version: input.visualVersion,
      asset_role: 'canonical_portrait', storage_bucket: BUCKET,
      storage_path: input.path, source_sha256: input.sha256,
      source_document: input.sourceDocument,
      approval_status: 'draft', rights_note: 'Source-provided artwork; rights require editorial verification'
    }),
    cache: 'no-store', signal: AbortSignal.timeout(10_000)
  });
  if (!response.ok) throw new Error(`Media registration failed: HTTP ${response.status}`);
}

/** Verify the bytes read back from private Storage, not merely the upload response. */
export async function verifyStoredCharacterOriginal(path: string, expectedSha256: string) {
  const { base, key } = credentials();
  const response = await fetch(`${base}/storage/v1/object/authenticated/${BUCKET}/${path}`, {
    headers: serviceHeaders(key), cache: 'no-store',
    signal: AbortSignal.timeout(20_000)
  });
  if (!response.ok) throw new Error(`Private media readback failed: HTTP ${response.status}`);
  const bytes = Buffer.from(await response.arrayBuffer());
  const actual = createHash('sha256').update(bytes).digest('hex');
  if (actual !== expectedSha256) throw new Error('Private media readback SHA-256 mismatch');
  return { sha256: actual, byteLength: bytes.length };
}
