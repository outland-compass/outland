import { NextRequest, NextResponse } from 'next/server';
import { authorize } from '@/lib/studio/auth';

export async function proxy(request: NextRequest) {
  const response = NextResponse.next();
  if (await authorize(request, response)) {
    response.headers.set('Cache-Control', 'private, no-store');
    response.headers.set('X-Robots-Tag', 'noindex, nofollow, noarchive');
    return response;
  }
  if (request.nextUrl.pathname.startsWith('/api/studio/')) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  const url = request.nextUrl.clone();
  url.pathname = '/';
  url.search = '';
  return NextResponse.redirect(url);
}

export const config = { matcher: ['/studio/:path*', '/api/studio/:path*'] };
