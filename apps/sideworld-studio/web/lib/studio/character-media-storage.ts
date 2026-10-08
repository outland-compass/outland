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
  const response = await fetch(`${base}/rest/v1/rpc/sideworld_character_media_character_in_scope`, {
    method: 'POST',
    headers: { ...serviceHeaders(key), 'Content-Type': 'application/json' },
    body: JSON.stringify({ p_character_id: characterId, p_universe_slug: universeSlug }),
    cache: 'no-store', signal: AbortSignal.timeout(10_000)
  });
  if (!response.ok) throw new Error(`Character scope RPC failed: HTTP ${response.status}`);
  return await response.json() === true;
}

export async function registerCharacterOriginal(input: {
  characterId: string; visualVersion: number; path: string; sha256: string; sourceDocument: string;
}) {
  const { base, key } = credentials();
  const response = await fetch(`${base}/rest/v1/rpc/sideworld_character_media_register`, {
    method: 'POST',
    headers: { ...serviceHeaders(key), 'Content-Type': 'application/json' },
    body: JSON.stringify({
      p_character_id: input.characterId, p_universe_slug: 'the-uncharted',
      p_visual_version: input.visualVersion, p_storage_path: input.path,
      p_source_sha256: input.sha256, p_source_document: input.sourceDocument
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
