import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { cookies } from 'next/headers';

import { SESSION_COOKIE, verifySession } from '@/lib/session';

const MEDIA = {
  'passport.webp': { file: 'passport.webp', type: 'image/webp' },
  'rafter-hero.webp': { file: 'rafter-hero.webp', type: 'image/webp' }
} as const;

export const runtime = 'nodejs';

export async function GET(
  _request: Request,
  { params }: { params: Promise<{ name: string }> }
) {
  const session = (await cookies()).get(SESSION_COOKIE)?.value;
  if (!session || !verifySession(session)) {
    return new Response('Not found', { status: 404 });
  }

  const { name } = await params;
  const media = MEDIA[name as keyof typeof MEDIA];

  if (!media) return new Response('Not found', { status: 404 });

  try {
    const bytes = await readFile(path.join(process.cwd(), 'private-assets', media.file));
    return new Response(bytes, {
      headers: {
        'Content-Type': media.type,
        'Cache-Control': 'private, max-age=3600',
        'X-Content-Type-Options': 'nosniff'
      }
    });
  } catch {
    return new Response('Not found', { status: 404 });
  }
}
